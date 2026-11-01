package com.mkvenompro.optimizer.toolkit

import android.content.Context
import android.hardware.usb.UsbManager
import android.content.pm.PackageManager

data class UsbHostStatus(val supported: Boolean, val connectedDevices: Int)

fun readUsbHostStatus(context: Context): UsbHostStatus {
    val supported = context.packageManager.hasSystemFeature(PackageManager.FEATURE_USB_HOST)
    val manager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    return UsbHostStatus(supported, manager.deviceList.size)
}
