package com.unsafie.vpn

object NativeCore {
  init {
    System.loadLibrary("unsafie_core")
  }

  external fun startTunnel(
    fd: Int,
    mtu: Int,
  ): Int

  external fun stopTunnel()

  external fun isRunning(): Boolean

  external fun getVpnIp(): String

  external fun protectSocket(socketFd: Int): Int
}
