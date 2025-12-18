package com.paylog.app

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class SmsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    
    companion object {
        private const val TAG = "SmsPlugin"
        private const val METHOD_CHANNEL = "flutter_sms_parser/methods"
        private const val EVENT_CHANNEL = "flutter_sms_parser/sms_stream"
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val PERMISSION_TIMEOUT_MS = 30000L // 30 seconds timeout for permission requests
        
        private val REQUIRED_PERMISSIONS = arrayOf(
            Manifest.permission.READ_SMS,
            Manifest.permission.RECEIVE_SMS
        )
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var pendingResult: MethodChannel.Result? = null
    private var permissionTimeoutHandler: Handler? = null
    private var permissionTimeoutRunnable: Runnable? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
        
        Log.d(TAG, "SmsPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        context = null
        Log.d(TAG, "SmsPlugin detached from engine")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        Log.d(TAG, "SmsPlugin attached to activity")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Method call received: ${call.method}")
            when (call.method) {
                "requestPermissions" -> requestPermissions(result)
                "checkPermissions" -> checkPermissions(result)
                "startListening" -> startListening(result)
                "stopListening" -> stopListening(result)
                "getReceiverDebugInfo" -> getReceiverDebugInfo(result)
                "testReceiverRegistration" -> testReceiverRegistration(result)
                "testPlatformChannelConnectivity" -> testPlatformChannelConnectivity(result)
                "simulateSmsReceived" -> simulateSmsReceived(call, result)
                "startBackgroundService" -> startBackgroundService(result)
                "stopBackgroundService" -> stopBackgroundService(result)
                "isBackgroundServiceRunning" -> isBackgroundServiceRunning(result)
                "requestBatteryOptimizationExemption" -> requestBatteryOptimizationExemption(result)
                "isBatteryOptimizationIgnored" -> isBatteryOptimizationIgnored(result)
                else -> {
                    Log.w(TAG, "Unknown method call: ${call.method}")
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling method call ${call.method}: ${e.message}", e)
            result.error("METHOD_CALL_ERROR", "Error handling method call: ${e.message}", e.toString())
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Requesting SMS permissions")
            val activity = this.activity
            if (activity == null) {
                Log.e(TAG, "Activity not available for permission request")
                result.error("NO_ACTIVITY", "Activity not available for permission request", null)
                return
            }

            val missingPermissions = REQUIRED_PERMISSIONS.filter { permission ->
                val status = ContextCompat.checkSelfPermission(activity, permission)
                Log.d(TAG, "Permission $permission status: ${if (status == PackageManager.PERMISSION_GRANTED) "GRANTED" else "DENIED"}")
                status != PackageManager.PERMISSION_GRANTED
            }

            if (missingPermissions.isEmpty()) {
                Log.d(TAG, "All SMS permissions already granted")
                result.success(true)
                return
            }

            Log.d(TAG, "Missing permissions: ${missingPermissions.joinToString(", ")}")
            
            // Clear any existing timeout
            clearPermissionTimeout()
            
            // Set up timeout for permission request
            setupPermissionTimeout(result)
            
            pendingResult = result
            ActivityCompat.requestPermissions(
                activity,
                missingPermissions.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
            
            Log.d(TAG, "Permission request dialog shown")
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting permissions: ${e.message}", e)
            result.error("PERMISSION_REQUEST_ERROR", "Error requesting permissions: ${e.message}", e.toString())
        }
    }

    private fun checkPermissions(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Checking SMS permissions")
            val context = this.context
            if (context == null) {
                Log.e(TAG, "Context not available for permission check")
                result.error("NO_CONTEXT", "Context not available for permission check", null)
                return
            }

            val permissionStatus = REQUIRED_PERMISSIONS.associate { permission ->
                val status = ContextCompat.checkSelfPermission(context, permission)
                val granted = status == PackageManager.PERMISSION_GRANTED
                Log.d(TAG, "Permission $permission: ${if (granted) "GRANTED" else "DENIED"}")
                permission to granted
            }

            val allGranted = permissionStatus.values.all { it }
            Log.d(TAG, "All permissions granted: $allGranted")
            
            result.success(mapOf(
                "allGranted" to allGranted,
                "permissions" to permissionStatus
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Error checking permissions: ${e.message}", e)
            result.error("PERMISSION_CHECK_ERROR", "Error checking permissions: ${e.message}", e.toString())
        }
    }

    private fun startListening(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Starting SMS listening")
            val context = this.context
            if (context == null) {
                Log.e(TAG, "Context not available for starting SMS listening")
                result.error("NO_CONTEXT", "Context not available for starting SMS listening", null)
                return
            }

            // Check if permissions are granted
            val missingPermissions = REQUIRED_PERMISSIONS.filter { permission ->
                val status = ContextCompat.checkSelfPermission(context, permission)
                status != PackageManager.PERMISSION_GRANTED
            }

            if (missingPermissions.isNotEmpty()) {
                Log.e(TAG, "SMS permissions not granted. Missing: ${missingPermissions.joinToString(", ")}")
                result.error("PERMISSIONS_DENIED", 
                    "SMS permissions not granted. Missing: ${missingPermissions.joinToString(", ")}", 
                    mapOf("missingPermissions" to missingPermissions))
                return
            }

            // Verify EventChannel is set up
            if (SmsReceiver.eventSink == null) {
                Log.w(TAG, "EventChannel not connected, but SMS listening can still start")
            }

            Log.d(TAG, "SMS listening started successfully - BroadcastReceiver is registered via manifest")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting SMS listening: ${e.message}", e)
            result.error("START_LISTENING_ERROR", "Error starting SMS listening: ${e.message}", e.toString())
        }
    }

    private fun stopListening(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Stopping SMS listening")
            SmsReceiver.eventSink = null
            Log.d(TAG, "SMS listening stopped successfully")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping SMS listening: ${e.message}", e)
            result.error("STOP_LISTENING_ERROR", "Error stopping SMS listening: ${e.message}", e.toString())
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "EventChannel listener attached")
        SmsReceiver.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "EventChannel listener cancelled")
        SmsReceiver.eventSink = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) {
            return false
        }

        Log.d(TAG, "Permission request result received")
        
        // Clear timeout
        clearPermissionTimeout()
        
        val result = pendingResult
        pendingResult = null

        if (result == null) {
            Log.w(TAG, "No pending result for permission request")
            return true
        }

        try {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            
            // Log individual permission results
            permissions.forEachIndexed { index, permission ->
                val granted = if (index < grantResults.size) grantResults[index] == PackageManager.PERMISSION_GRANTED else false
                Log.d(TAG, "Permission $permission: ${if (granted) "GRANTED" else "DENIED"}")
            }
            
            Log.d(TAG, "All permissions granted: $allGranted")
            result.success(allGranted)
        } catch (e: Exception) {
            Log.e(TAG, "Error processing permission result: ${e.message}", e)
            result.error("PERMISSION_RESULT_ERROR", "Error processing permission result: ${e.message}", e.toString())
        }
        
        return true
    }
    
    private fun setupPermissionTimeout(result: MethodChannel.Result) {
        permissionTimeoutHandler = Handler(Looper.getMainLooper())
        permissionTimeoutRunnable = Runnable {
            Log.w(TAG, "Permission request timed out")
            val pendingResult = this.pendingResult
            this.pendingResult = null
            
            if (pendingResult != null) {
                pendingResult.error("PERMISSION_TIMEOUT", 
                    "Permission request timed out after ${PERMISSION_TIMEOUT_MS}ms", null)
            }
        }
        
        permissionTimeoutHandler?.postDelayed(permissionTimeoutRunnable!!, PERMISSION_TIMEOUT_MS)
    }
    
    private fun clearPermissionTimeout() {
        permissionTimeoutRunnable?.let { runnable ->
            permissionTimeoutHandler?.removeCallbacks(runnable)
        }
        permissionTimeoutHandler = null
        permissionTimeoutRunnable = null
    }
    
    private fun getReceiverDebugInfo(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Getting SMS receiver debug information")
            
            val debugInfo = SmsReceiver.getReceiverStatus()
            Log.d(TAG, "Receiver debug info: $debugInfo")
            
            result.success(debugInfo)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting receiver debug info: ${e.message}", e)
            result.error("DEBUG_INFO_ERROR", "Error getting receiver debug info: ${e.message}", e.toString())
        }
    }
    
    private fun testReceiverRegistration(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Testing SMS receiver registration")
            val context = this.context
            if (context == null) {
                Log.e(TAG, "Context not available for receiver registration test")
                result.error("NO_CONTEXT", "Context not available for receiver registration test", null)
                return
            }
            
            // Test if the receiver class can be instantiated
            val receiverClass = SmsReceiver::class.java
            Log.d(TAG, "Receiver class: ${receiverClass.name}")
            Log.d(TAG, "Receiver package: ${receiverClass.`package`?.name}")
            
            // Check if the receiver is declared in the manifest
            val packageManager = context.packageManager
            val packageInfo = packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_RECEIVERS
            )
            
            val receivers = packageInfo.receivers
            val smsReceiverFound = receivers?.any { receiver ->
                receiver.name == receiverClass.name || 
                receiver.name == ".SmsReceiver" ||
                receiver.name.endsWith("SmsReceiver")
            } ?: false
            
            Log.d(TAG, "SMS receiver found in manifest: $smsReceiverFound")
            if (receivers != null) {
                Log.d(TAG, "All receivers in manifest:")
                for (receiver in receivers) {
                    Log.d(TAG, "  - ${receiver.name}")
                }
            }
            
            val testResult = mapOf(
                "receiverClassExists" to true,
                "receiverClassName" to receiverClass.name,
                "receiverPackage" to (receiverClass.`package`?.name ?: "unknown"),
                "manifestRegistrationFound" to smsReceiverFound,
                "contextPackageName" to context.packageName,
                "totalReceiversInManifest" to (receivers?.size ?: 0)
            )
            
            Log.d(TAG, "Receiver registration test result: $testResult")
            result.success(testResult)
        } catch (e: Exception) {
            Log.e(TAG, "Error testing receiver registration: ${e.message}", e)
            result.error("RECEIVER_TEST_ERROR", "Error testing receiver registration: ${e.message}", e.toString())
        }
    }
    
    private fun testPlatformChannelConnectivity(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Testing platform channel connectivity")
            val startTime = System.currentTimeMillis()
            
            val connectivityTest = mutableMapOf<String, Any>()
            
            // Test 1: Method channel response time
            val methodChannelStart = System.currentTimeMillis()
            connectivityTest["methodChannelResponseTime"] = System.currentTimeMillis() - methodChannelStart
            
            // Test 2: Context availability
            val context = this.context
            connectivityTest["contextAvailable"] = context != null
            connectivityTest["contextPackageName"] = context?.packageName ?: "unknown"
            
            // Test 3: Activity availability
            connectivityTest["activityAvailable"] = activity != null
            connectivityTest["activityClassName"] = activity?.javaClass?.name ?: "unknown"
            
            // Test 4: EventChannel sink status
            connectivityTest["eventSinkAvailable"] = SmsReceiver.eventSink != null
            
            // Test 5: Permission status
            if (context != null) {
                val permissionStatus = REQUIRED_PERMISSIONS.associate { permission ->
                    val status = ContextCompat.checkSelfPermission(context, permission)
                    permission to (status == PackageManager.PERMISSION_GRANTED)
                }
                connectivityTest["permissionStatus"] = permissionStatus
            }
            
            // Test 6: Platform channel method call latency
            val totalTime = System.currentTimeMillis() - startTime
            connectivityTest["totalTestTime"] = totalTime
            connectivityTest["testTimestamp"] = System.currentTimeMillis()
            
            // Overall connectivity status
            val isConnected = context != null && 
                             (SmsReceiver.eventSink != null || activity != null)
            connectivityTest["overallConnectivity"] = isConnected
            
            Log.d(TAG, "Platform channel connectivity test completed in ${totalTime}ms")
            Log.d(TAG, "Connectivity test results: $connectivityTest")
            
            result.success(connectivityTest)
        } catch (e: Exception) {
            Log.e(TAG, "Error testing platform channel connectivity: ${e.message}", e)
            result.error("CONNECTIVITY_TEST_ERROR", "Error testing platform channel connectivity: ${e.message}", e.toString())
        }
    }
    
    private fun simulateSmsReceived(call: MethodCall, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Simulating SMS received for testing")
            
            // Get test SMS data from method call arguments
            val arguments = call.arguments as? Map<String, Any>
            val testSender = arguments?.get("sender") as? String ?: "TEST-SENDER"
            val testContent = arguments?.get("content") as? String ?: "Test SMS message for platform channel testing"
            val testTimestamp = arguments?.get("timestamp") as? Long ?: System.currentTimeMillis()
            val testThreadId = arguments?.get("threadId") as? String
            
            Log.d(TAG, "Simulating SMS from: $testSender")
            Log.d(TAG, "SMS content: $testContent")
            
            // Create test SMS data
            val testSmsData = mapOf(
                "sender" to testSender,
                "content" to testContent,
                "timestamp" to testTimestamp,
                "threadId" to testThreadId,
                "receivedAt" to System.currentTimeMillis(),
                "contentLength" to testContent.length,
                "isValidData" to true,
                "isSimulated" to true
            )
            
            // Send to Flutter via EventChannel if available
            val sink = SmsReceiver.eventSink
            if (sink != null) {
                try {
                    sink.success(testSmsData)
                    Log.d(TAG, "Simulated SMS data sent to Flutter successfully")
                    
                    result.success(mapOf(
                        "success" to true,
                        "message" to "Simulated SMS sent to Flutter",
                        "smsData" to testSmsData
                    ))
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending simulated SMS to Flutter: ${e.message}", e)
                    result.success(mapOf(
                        "success" to false,
                        "error" to "Failed to send to Flutter: ${e.message}",
                        "smsData" to testSmsData
                    ))
                }
            } else {
                Log.w(TAG, "EventChannel sink not available for simulated SMS")
                result.success(mapOf(
                    "success" to false,
                    "error" to "EventChannel sink not available",
                    "smsData" to testSmsData
                ))
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error simulating SMS received: ${e.message}", e)
            result.error("SMS_SIMULATION_ERROR", "Error simulating SMS received: ${e.message}", e.toString())
        }
    }
    
    private fun startBackgroundService(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Starting background SMS monitoring service")
            val context = this.context
            if (context == null) {
                Log.e(TAG, "Context not available for starting background service")
                result.error("NO_CONTEXT", "Context not available for starting background service", null)
                return
            }
            
            val serviceIntent = Intent(context, SmsMonitoringService::class.java)
            serviceIntent.action = SmsMonitoringService.ACTION_START_MONITORING
            
            context.startForegroundService(serviceIntent)
            
            Log.d(TAG, "Background SMS monitoring service started")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting background service: ${e.message}", e)
            result.error("BACKGROUND_SERVICE_ERROR", "Error starting background service: ${e.message}", e.toString())
        }
    }
    
    private fun stopBackgroundService(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Stopping background SMS monitoring service")
            val context = this.context
            if (context == null) {
                Log.e(TAG, "Context not available for stopping background service")
                result.error("NO_CONTEXT", "Context not available for stopping background service", null)
                return
            }
            
            val serviceIntent = Intent(context, SmsMonitoringService::class.java)
            serviceIntent.action = SmsMonitoringService.ACTION_STOP_MONITORING
            
            context.startService(serviceIntent)
            
            Log.d(TAG, "Background SMS monitoring service stopped")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping background service: ${e.message}", e)
            result.error("BACKGROUND_SERVICE_ERROR", "Error stopping background service: ${e.message}", e.toString())
        }
    }
    
    private fun isBackgroundServiceRunning(result: MethodChannel.Result) {
        try {
            val context = this.context
            if (context == null) {
                result.error("NO_CONTEXT", "Context not available", null)
                return
            }
            
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val runningServices = activityManager.getRunningServices(Integer.MAX_VALUE)
            
            val isRunning = runningServices.any { service ->
                service.service.className == SmsMonitoringService::class.java.name
            }
            
            Log.d(TAG, "Background service running: $isRunning")
            result.success(isRunning)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking background service status: ${e.message}", e)
            result.error("SERVICE_CHECK_ERROR", "Error checking background service status: ${e.message}", e.toString())
        }
    }
    
    private fun requestBatteryOptimizationExemption(result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Requesting battery optimization exemption")
            val context = this.context
            val activity = this.activity
            
            if (context == null || activity == null) {
                Log.e(TAG, "Context or activity not available for battery optimization request")
                result.error("NO_CONTEXT_ACTIVITY", "Context or activity not available", null)
                return
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                
                if (!powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:${context.packageName}")
                    activity.startActivity(intent)
                    
                    Log.d(TAG, "Battery optimization exemption dialog shown")
                    result.success(true)
                } else {
                    Log.d(TAG, "Battery optimization already ignored")
                    result.success(true)
                }
            } else {
                Log.d(TAG, "Battery optimization not applicable for this Android version")
                result.success(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting battery optimization exemption: ${e.message}", e)
            result.error("BATTERY_OPTIMIZATION_ERROR", "Error requesting battery optimization exemption: ${e.message}", e.toString())
        }
    }
    
    private fun isBatteryOptimizationIgnored(result: MethodChannel.Result) {
        try {
            val context = this.context
            if (context == null) {
                result.error("NO_CONTEXT", "Context not available", null)
                return
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val isIgnored = powerManager.isIgnoringBatteryOptimizations(context.packageName)
                
                Log.d(TAG, "Battery optimization ignored: $isIgnored")
                result.success(isIgnored)
            } else {
                Log.d(TAG, "Battery optimization not applicable for this Android version")
                result.success(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking battery optimization status: ${e.message}", e)
            result.error("BATTERY_CHECK_ERROR", "Error checking battery optimization status: ${e.message}", e.toString())
        }
    }
}