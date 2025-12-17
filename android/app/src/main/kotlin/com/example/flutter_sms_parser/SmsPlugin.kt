package com.paylog.app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
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
        when (call.method) {
            "requestPermissions" -> requestPermissions(result)
            "checkPermissions" -> checkPermissions(result)
            "startListening" -> startListening(result)
            "stopListening" -> stopListening(result)
            else -> result.notImplemented()
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        val activity = this.activity
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        val missingPermissions = REQUIRED_PERMISSIONS.filter { permission ->
            ContextCompat.checkSelfPermission(activity, permission) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isEmpty()) {
            result.success(true)
            return
        }

        pendingResult = result
        ActivityCompat.requestPermissions(
            activity,
            missingPermissions.toTypedArray(),
            PERMISSION_REQUEST_CODE
        )
    }

    private fun checkPermissions(result: MethodChannel.Result) {
        val context = this.context
        if (context == null) {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        val permissionStatus = REQUIRED_PERMISSIONS.associate { permission ->
            val status = ContextCompat.checkSelfPermission(context, permission)
            permission to (status == PackageManager.PERMISSION_GRANTED)
        }

        val allGranted = permissionStatus.values.all { it }
        
        result.success(mapOf(
            "allGranted" to allGranted,
            "permissions" to permissionStatus
        ))
    }

    private fun startListening(result: MethodChannel.Result) {
        val context = this.context
        if (context == null) {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        // Check if permissions are granted
        val hasPermissions = REQUIRED_PERMISSIONS.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
        }

        if (!hasPermissions) {
            result.error("PERMISSIONS_DENIED", "SMS permissions not granted", null)
            return
        }

        Log.d(TAG, "SMS listening started - BroadcastReceiver is registered via manifest")
        result.success(true)
    }

    private fun stopListening(result: MethodChannel.Result) {
        Log.d(TAG, "SMS listening stopped")
        SmsReceiver.eventSink = null
        result.success(true)
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

        val result = pendingResult
        pendingResult = null

        if (result == null) {
            return true
        }

        val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        result.success(allGranted)
        
        return true
    }
}