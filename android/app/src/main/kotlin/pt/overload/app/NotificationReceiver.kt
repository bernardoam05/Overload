package pt.overload.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Receives notification button taps, the rest alarm and reminder alarms. */
class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (val action = intent.action) {
            WorkoutNotifier.ACTION_REST_DONE -> WorkoutNotifier.onRestFinished(context)
            WorkoutNotifier.ACTION_REMINDER -> WorkoutNotifier.onReminder(context, intent)
            WorkoutNotifier.ACTION_REST_MINUS,
            WorkoutNotifier.ACTION_REST_PLUS,
            WorkoutNotifier.ACTION_REST_SKIP,
            -> if (action != null) WorkoutNotifier.onRestAction(context, action)
        }
    }
}
