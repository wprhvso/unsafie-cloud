package com.unsafie.vpn

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor

class UnsafieVpnService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val vpnIp = try {
            NativeCore.getVpnIp()
        } catch (e: UnsatisfiedLinkError) {
            "10.42.10.15"
        }

        val builder = Builder()
            .setSession("UnsafieCloud")
            .setMtu(1420)
            .addAddress(vpnIp, 16)
            .addRoute("10.42.0.0", 16)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("10.42.0.1")

        vpnInterface = builder.establish()
        vpnInterface?.let { pfd ->
            NativeCore.startTunnel(pfd.detachFd(), 1420)
        }

        return START_STICKY
    }

    override fun onDestroy() {
        NativeCore.stopTunnel()
        vpnInterface?.close()
        vpnInterface = null
        super.onDestroy()
    }
}
