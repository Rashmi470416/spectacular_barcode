package com.zequetech.spectacular_barcode

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

/** SpectacularBarcodePlugin */
class SpectacularBarcodePlugin : FlutterPlugin, ActivityAware {
    private var activityPluginBinding: ActivityPluginBinding? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var methodCallHandler: SpectacularBarcodeHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = null
    }

    override fun onAttachedToActivity(activityPluginBinding: ActivityPluginBinding) {
        val pluginBinding = flutterPluginBinding ?: return
        val binaryMessenger = pluginBinding.binaryMessenger

        methodCallHandler = SpectacularBarcodeHandler(
            activityPluginBinding.activity,
            BarcodeEventHandler(binaryMessenger),
            binaryMessenger,
            CameraPermissions(),
            activityPluginBinding::addRequestPermissionsResultListener,
            pluginBinding.textureRegistry,
        )

        this.activityPluginBinding = activityPluginBinding
    }

    override fun onDetachedFromActivity() {
        val binding = activityPluginBinding
        if (binding != null) {
            methodCallHandler?.dispose(binding)
        }
        methodCallHandler = null
        activityPluginBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}
