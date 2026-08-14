package com.zequetech.spectacular_barcode

import android.Manifest.permission
import android.app.Activity
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

internal class CameraPermissions {
    companion object {
        const val REQUEST_CODE = 0x0787
    }

    fun interface ResultCallback {
        fun onResult(errorCode: String?)
    }

    private var listener: RequestPermissionsResultListener? = null
    private var ongoing: Boolean = false

    fun getPermissionListener(): RequestPermissionsResultListener? = listener

    fun hasCameraPermission(activity: Activity): Int {
        val granted = ContextCompat.checkSelfPermission(
            activity,
            permission.CAMERA,
        ) == PackageManager.PERMISSION_GRANTED

        return if (granted) 1 else 2
    }

    fun requestPermission(
        activity: Activity,
        addPermissionListener: (RequestPermissionsResultListener) -> Unit,
        callback: ResultCallback,
    ) {
        if (ongoing) {
            callback.onResult(ErrorCodes.CAMERA_PERMISSIONS_REQUEST_ONGOING)
            return
        }

        if (hasCameraPermission(activity) == 1) {
            callback.onResult(null)
            return
        }

        if (listener == null) {
            listener = RequestPermissionsResultListener { requestCode, _, grantResults ->
                if (requestCode != REQUEST_CODE) {
                    return@RequestPermissionsResultListener false
                }

                ongoing = false
                listener = null

                if (grantResults.isEmpty() ||
                    grantResults[0] != PackageManager.PERMISSION_GRANTED
                ) {
                    callback.onResult(ErrorCodes.CAMERA_ACCESS_DENIED)
                } else {
                    callback.onResult(null)
                }
                true
            }
            addPermissionListener(listener!!)
        }

        ongoing = true
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(permission.CAMERA),
            REQUEST_CODE,
        )
    }
}
