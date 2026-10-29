package pt.overload.app

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/** Snapshot of the running workout, mirrored from Dart. */
data class WorkoutState(
    val name: String,
    val startedAt: Long,
    val setsDone: Int,
    val setsTotal: Int,
    val segments: List<Int>,
    val nextLabel: String?,
    val restEndsAt: Long,
    val restTotalSeconds: Int,
    val restAlerts: Boolean,
    val showOngoing: Boolean,
) {
    val resting: Boolean get() = restEndsAt > System.currentTimeMillis()

    fun toJson(): String = JSONObject().apply {
        put("name", name)
        put("startedAt", startedAt)
        put("setsDone", setsDone)
        put("setsTotal", setsTotal)
        put("segments", JSONArray(segments))
        put("nextLabel", nextLabel ?: JSONObject.NULL)
        put("restEndsAt", restEndsAt)
        put("restTotalSeconds", restTotalSeconds)
        put("restAlerts", restAlerts)
        put("showOngoing", showOngoing)
    }.toString()

    companion object {
        fun fromMap(m: Map<*, *>) = WorkoutState(
            name = m["name"] as? String ?: "Treino",
            startedAt = (m["startedAt"] as Number).toLong(),
            setsDone = (m["setsDone"] as? Number)?.toInt() ?: 0,
            setsTotal = (m["setsTotal"] as? Number)?.toInt() ?: 0,
            segments = (m["segments"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: emptyList(),
            nextLabel = m["nextLabel"] as? String,
            restEndsAt = (m["restEndsAt"] as? Number)?.toLong() ?: 0L,
            restTotalSeconds = (m["restTotalSeconds"] as? Number)?.toInt() ?: 0,
            restAlerts = m["restAlerts"] as? Boolean ?: true,
            showOngoing = m["showOngoing"] as? Boolean ?: true,
        )

        fun fromJson(s: String): WorkoutState? = try {
            val o = JSONObject(s)
            val seg = o.optJSONArray("segments") ?: JSONArray()
            WorkoutState(
                name = o.optString("name", "Treino"),
                startedAt = o.getLong("startedAt"),
                setsDone = o.optInt("setsDone"),
                setsTotal = o.optInt("setsTotal"),
                segments = List(seg.length()) { seg.getInt(it) },
                nextLabel = if (o.isNull("nextLabel")) null else o.optString("nextLabel"),
                restEndsAt = o.optLong("restEndsAt"),
                restTotalSeconds = o.optInt("restTotalSeconds"),
                restAlerts = o.optBoolean("restAlerts", true),
                showOngoing = o.optBoolean("showOngoing", true),
            )
        } catch (e: Exception) {
            null
        }
    }
}

/**
 * Owns every system notification of the app: the live workout notification
 * (promoted to a Live Update on Android 16), the end-of-rest alarm and the
 * scheduled reminders. State is persisted so notification actions and
 * alarms keep working while the Flutter engine is not running.
 */
object WorkoutNotifier {
    private const val CH_WORKOUT = "workout_live"
    private const val CH_REST = "rest_alerts"
    private const val CH_REMINDERS = "reminders"

    private const val ID_WORKOUT = 1
    private const val ID_REST_DONE = 2
    private const val ID_REMINDER_BASE = 100

    private const val PREFS = "overload_notifications"
    private const val KEY_STATE = "workout_state"
    private const val KEY_PENDING = "pending_actions"

    const val ACTION_REST_MINUS = "pt.overload.app.REST_MINUS"
    const val ACTION_REST_PLUS = "pt.overload.app.REST_PLUS"
    const val ACTION_REST_SKIP = "pt.overload.app.REST_SKIP"
    const val ACTION_REST_DONE = "pt.overload.app.REST_DONE"
    const val ACTION_REMINDER = "pt.overload.app.REMINDER"
    const val EXTRA_ROUTE = "route"

    private const val EMBER = 0xFFFF6A3D.toInt()
    private const val AMBER = 0xFFFFB547.toInt()

    /** Set while a Flutter engine is attached, so events reach Dart directly. */
    var channel: MethodChannel? = null

    /** True while the activity is resumed. */
    @Volatile var foreground = false

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun manager(ctx: Context) =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = manager(ctx)
        nm.createNotificationChannel(
            NotificationChannel(CH_WORKOUT, "Treino em curso", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Cronómetro, progresso e contagem do descanso em tempo real."
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            },
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_REST, "Fim do descanso", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Avisa quando o tempo de descanso termina."
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 350, 150, 350, 150, 600)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
            },
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_REMINDERS, "Lembretes", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Streak semanal em risco e treinos por terminar."
            },
        )
    }

    private fun builder(ctx: Context, channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, channelId)
        else @Suppress("DEPRECATION") Notification.Builder(ctx)

    private fun openAppIntent(ctx: Context, route: String, requestCode: Int): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java)
            .putExtra(EXTRA_ROUTE, route)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(
            ctx, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun broadcast(ctx: Context, action: String, requestCode: Int, extras: Bundle? = null): PendingIntent {
        val intent = Intent(ctx, NotificationReceiver::class.java).setAction(action)
        if (extras != null) intent.putExtras(extras)
        return PendingIntent.getBroadcast(
            ctx, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun canNotify(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return manager(ctx).areNotificationsEnabled()
    }

    fun canPromote(ctx: Context): Boolean? =
        if (Build.VERSION.SDK_INT >= 36) manager(ctx).canPostPromotedNotifications() else null

    fun canScheduleExact(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    // ---- Workout ---------------------------------------------------------------------

    fun loadState(ctx: Context): WorkoutState? =
        prefs(ctx).getString(KEY_STATE, null)?.let { WorkoutState.fromJson(it) }

    private fun saveState(ctx: Context, state: WorkoutState?) {
        prefs(ctx).edit().apply {
            if (state == null) remove(KEY_STATE) else putString(KEY_STATE, state.toJson())
        }.apply()
    }

    fun updateWorkout(ctx: Context, state: WorkoutState) {
        ensureChannels(ctx)
        val previous = loadState(ctx)
        saveState(ctx, state)
        if (state.resting && previous?.restEndsAt != state.restEndsAt) {
            manager(ctx).cancel(ID_REST_DONE)
        }
        scheduleRestAlarm(ctx, state)
        postWorkout(ctx, state)
        // Dart may notice the end of the rest before the alarm does; it then
        // clears the rest (cancelling the alarm), so alert from here instead.
        // A rest skipped early still had time left and stays silent.
        val expired = previous != null && previous.restEndsAt != 0L && !state.resting &&
            previous.restEndsAt - System.currentTimeMillis() <= 1500
        if (expired && previous!!.restAlerts) alertRestDone(ctx, previous)
    }

    fun clearWorkout(ctx: Context) {
        saveState(ctx, null)
        cancelRestAlarm(ctx)
        manager(ctx).cancel(ID_WORKOUT)
        manager(ctx).cancel(ID_REST_DONE)
    }

    private fun postWorkout(ctx: Context, s: WorkoutState) {
        if (!s.showOngoing || !canNotify(ctx)) {
            manager(ctx).cancel(ID_WORKOUT)
            return
        }
        val resting = s.resting
        val b = builder(ctx, CH_WORKOUT)
            .setGroup("overload.workout")
            .setSmallIcon(R.drawable.ic_stat_overload)
            .setColor(EMBER)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(if (Build.VERSION.SDK_INT >= 31) Notification.CATEGORY_WORKOUT else Notification.CATEGORY_PROGRESS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(openAppIntent(ctx, "/workout", 1))
            .setShowWhen(true)
            .setUsesChronometer(true)

        val sets = if (s.setsTotal > 0) "${s.setsDone}/${s.setsTotal} séries" else "${s.setsDone} séries"
        if (resting) {
            b.setContentTitle("Descanso")
                .setContentText(s.nextLabel?.let { "A seguir: $it" } ?: sets)
                .setSubText(s.name)
                .setWhen(s.restEndsAt)
            if (Build.VERSION.SDK_INT >= 24) b.setChronometerCountDown(true)
            b.addAction(action(ctx, "−15 s", ACTION_REST_MINUS, 11))
            b.addAction(action(ctx, "+15 s", ACTION_REST_PLUS, 12))
            b.addAction(action(ctx, "Saltar", ACTION_REST_SKIP, 13))
        } else {
            b.setContentTitle(s.name)
                .setContentText(listOfNotNull(sets, s.nextLabel?.let { "A seguir: $it" }).joinToString(" · "))
                .setWhen(s.startedAt)
            if (Build.VERSION.SDK_INT >= 24) b.setChronometerCountDown(false)
        }

        if (s.setsTotal > 0) {
            if (Build.VERSION.SDK_INT >= 36) {
                val segments = s.segments.filter { it > 0 }.ifEmpty { listOf(s.setsTotal) }
                b.setStyle(
                    Notification.ProgressStyle()
                        .setStyledByProgress(true)
                        .setProgressSegments(
                            segments.mapIndexed { i, len ->
                                Notification.ProgressStyle.Segment(len).setColor(if (i % 2 == 0) EMBER else AMBER)
                            },
                        )
                        .setProgressTrackerIcon(Icon.createWithResource(ctx, R.drawable.ic_stat_overload))
                        .setProgress(s.setsDone.coerceIn(0, segments.sum())),
                )
            } else {
                b.setProgress(s.setsTotal, s.setsDone.coerceIn(0, s.setsTotal), false)
            }
        }

        if (Build.VERSION.SDK_INT >= 36) {
            // Asks the system to show this as a Live Update (status bar chip,
            // lock screen and always-on display).
            b.addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
        }
        manager(ctx).notify(ID_WORKOUT, b.build())
    }

    private fun action(ctx: Context, title: String, action: String, code: Int): Notification.Action =
        Notification.Action.Builder(
            Icon.createWithResource(ctx, R.drawable.ic_stat_overload), title, broadcast(ctx, action, code),
        ).build()

    // ---- Rest alarm --------------------------------------------------------------------

    private fun restAlarmIntent(ctx: Context) = broadcast(ctx, ACTION_REST_DONE, 10)

    private fun scheduleRestAlarm(ctx: Context, s: WorkoutState) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = restAlarmIntent(ctx)
        am.cancel(pi)
        if (!s.resting) return
        if (canScheduleExact(ctx)) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, s.restEndsAt, pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, s.restEndsAt, pi)
        }
    }

    private fun cancelRestAlarm(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(restAlarmIntent(ctx))
    }

    /** Called by the alarm when the rest period is over. */
    fun onRestFinished(ctx: Context) {
        val s = loadState(ctx) ?: return
        // Ignore stale alarms (rest skipped or extended meanwhile).
        if (s.restEndsAt == 0L || s.restEndsAt - System.currentTimeMillis() > 1500) return
        val next = s.copy(restEndsAt = 0L)
        saveState(ctx, next)
        postWorkout(ctx, next)
        if (s.restAlerts) alertRestDone(ctx, s)
        dispatch(ctx, "rest_done")
    }

    private fun alertRestDone(ctx: Context, s: WorkoutState) {
        if (foreground || !canNotify(ctx)) {
            vibrate(ctx)
            try {
                RingtoneManager.getRingtone(ctx, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))?.play()
            } catch (_: Exception) {
            }
            return
        }
        val b = builder(ctx, CH_REST)
            .setGroup("overload.rest")
            .setSmallIcon(R.drawable.ic_stat_overload)
            .setColor(EMBER)
            .setContentTitle("Descanso terminado 💪")
            .setContentText(s.nextLabel?.let { "A seguir: $it" } ?: "Hora da próxima série.")
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(ctx, "/workout", 2))
        if (Build.VERSION.SDK_INT >= 26) b.setTimeoutAfter(3 * 60 * 1000L)
        if (Build.VERSION.SDK_INT < 26) {
            @Suppress("DEPRECATION")
            b.setPriority(Notification.PRIORITY_HIGH).setDefaults(Notification.DEFAULT_ALL)
        }
        manager(ctx).notify(ID_REST_DONE, b.build())
    }

    fun cancelRestAlert(ctx: Context) = manager(ctx).cancel(ID_REST_DONE)

    private fun vibrate(ctx: Context) {
        val pattern = longArrayOf(0, 350, 150, 350, 150, 600)
        val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= 31) {
            (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (vibrator?.hasVibrator() != true) return
        if (Build.VERSION.SDK_INT >= 26) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
    }

    /** Handles the rest buttons of the live notification. */
    fun onRestAction(ctx: Context, action: String) {
        val s = loadState(ctx) ?: return
        val now = System.currentTimeMillis()
        val next = when (action) {
            ACTION_REST_SKIP -> s.copy(restEndsAt = 0L)
            ACTION_REST_PLUS, ACTION_REST_MINUS -> {
                if (!s.resting) return
                val delta = if (action == ACTION_REST_PLUS) 15_000L else -15_000L
                val end = s.restEndsAt + delta
                if (end <= now) s.copy(restEndsAt = 0L)
                else s.copy(restEndsAt = end, restTotalSeconds = (s.restTotalSeconds + (delta / 1000).toInt()).coerceAtLeast(1))
            }
            else -> return
        }
        saveState(ctx, next)
        scheduleRestAlarm(ctx, next)
        postWorkout(ctx, next)
        dispatch(
            ctx,
            when (action) {
                ACTION_REST_PLUS -> "rest_plus"
                ACTION_REST_MINUS -> "rest_minus"
                else -> "rest_skip"
            },
        )
    }

    // ---- Reminders ---------------------------------------------------------------------

    private const val MAX_REMINDERS = 5

    private fun reminderIntent(ctx: Context, slot: Int, extras: Bundle? = null) =
        broadcast(ctx, ACTION_REMINDER, 200 + slot, extras)

    fun setReminders(ctx: Context, reminders: List<Map<*, *>>) {
        ensureChannels(ctx)
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (slot in 0 until MAX_REMINDERS) am.cancel(reminderIntent(ctx, slot))
        reminders.take(MAX_REMINDERS).forEachIndexed { slot, r ->
            val at = (r["at"] as? Number)?.toLong() ?: return@forEachIndexed
            if (at <= System.currentTimeMillis()) return@forEachIndexed
            val extras = Bundle().apply {
                putInt("id", (r["id"] as? Number)?.toInt() ?: slot)
                putString("title", r["title"] as? String ?: "Overload")
                putString("body", r["body"] as? String ?: "")
                putString("route", r["route"] as? String ?: "/home")
                putBoolean("requiresWorkout", r["requiresWorkout"] as? Boolean ?: false)
            }
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, reminderIntent(ctx, slot, extras))
        }
    }

    fun onReminder(ctx: Context, intent: Intent) {
        if (intent.getBooleanExtra("requiresWorkout", false) && loadState(ctx) == null) return
        if (!canNotify(ctx)) return
        ensureChannels(ctx)
        val id = intent.getIntExtra("id", 0)
        val route = intent.getStringExtra("route") ?: "/home"
        val b = builder(ctx, CH_REMINDERS)
            .setGroup("overload.reminder.$id")
            .setSmallIcon(R.drawable.ic_stat_overload)
            .setColor(EMBER)
            .setContentTitle(intent.getStringExtra("title"))
            .setContentText(intent.getStringExtra("body"))
            .setStyle(Notification.BigTextStyle().bigText(intent.getStringExtra("body")))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(ctx, route, 300 + id))
        manager(ctx).notify(ID_REMINDER_BASE + id, b.build())
    }

    // ---- Dart bridge -------------------------------------------------------------------

    /** Sends an action to Dart, or queues it until the app runs again. */
    private fun dispatch(ctx: Context, action: String) {
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("onAction", action)
            return
        }
        val p = prefs(ctx)
        val queue = JSONArray(p.getString(KEY_PENDING, "[]"))
        queue.put(action)
        p.edit().putString(KEY_PENDING, queue.toString()).apply()
    }

    fun takePendingActions(ctx: Context): List<String> {
        val p = prefs(ctx)
        val queue = JSONArray(p.getString(KEY_PENDING, "[]"))
        p.edit().remove(KEY_PENDING).apply()
        return List(queue.length()) { queue.getString(it) }
    }
}
