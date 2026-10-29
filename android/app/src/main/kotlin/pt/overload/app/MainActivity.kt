package pt.overload.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var launchRoute: String? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WorkoutNotifier.ensureChannels(this)
        launchRoute = intent?.getStringExtra(WorkoutNotifier.EXTRA_ROUTE)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "overload/notifications")
        WorkoutNotifier.channel = channel
        registerInstaller(flutterEngine)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWorkout" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) result.error("args", "Missing workout", null)
                    else {
                        WorkoutNotifier.updateWorkout(this, WorkoutState.fromMap(args))
                        result.success(null)
                    }
                }
                "clearWorkout" -> {
                    WorkoutNotifier.clearWorkout(this)
                    result.success(null)
                }
                "cancelRestAlert" -> {
                    WorkoutNotifier.cancelRestAlert(this)
                    result.success(null)
                }
                "setReminders" -> {
                    val list = (call.arguments as? List<*>)?.filterIsInstance<Map<*, *>>() ?: emptyList()
                    WorkoutNotifier.setReminders(this, list)
                    result.success(null)
                }
                "takePendingActions" -> result.success(WorkoutNotifier.takePendingActions(this))
                "takeLaunchRoute" -> {
                    result.success(launchRoute)
                    launchRoute = null
                }
                "status" -> result.success(
                    mapOf(
                        "notifications" to WorkoutNotifier.canNotify(this),
                        "promoted" to WorkoutNotifier.canPromote(this),
                        "exactAlarms" to WorkoutNotifier.canScheduleExact(this),
                    ),
                )
                "requestPermission" -> requestNotificationPermission(result)
                "openSettings" -> {
                    openSettings(call.arguments as? String)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun registerInstaller(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "overload/installer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "abis" -> result.success(Build.SUPPORTED_ABIS.toList())
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls(),
                    )
                    "openInstallSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")),
                        )
                        result.success(null)
                    }
                    "install" -> try {
                        ApkInstaller.install(this, call.arguments as String)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install", e.message, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        WorkoutNotifier.channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        WorkoutNotifier.foreground = true
    }

    override fun onPause() {
        WorkoutNotifier.foreground = false
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val route = intent.getStringExtra(WorkoutNotifier.EXTRA_ROUTE) ?: return
        WorkoutNotifier.channel?.invokeMethod("openRoute", route) ?: run { launchRoute = route }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(WorkoutNotifier.canNotify(this))
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST)
    }

    @Deprecated("Deprecated in Java")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST) return
        pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
    }

    private fun openSettings(which: String?) {
        val intent = when {
            which == "promotion" && Build.VERSION.SDK_INT >= 36 ->
                Intent(Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            which == "exactAlarms" && Build.VERSION.SDK_INT >= 31 ->
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))
            Build.VERSION.SDK_INT >= 26 ->
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        }
    }

    companion object {
        private const val PERMISSION_REQUEST = 4021
    }
}
