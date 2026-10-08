package com.pickixo.polyscan_scanner

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.ArgumentMatchers.anyString
import org.mockito.ArgumentMatchers.isNull
import org.mockito.Mockito
import kotlin.test.Test

internal class PolyscanScannerPluginTest {
    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        PolyscanScannerPlugin().onMethodCall(MethodCall("noSuchMethod", null), result)
        Mockito.verify(result).notImplemented()
    }

    @Test
    fun scan_withoutActivity_fails() {
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        PolyscanScannerPlugin().onMethodCall(MethodCall("scan", null), result)
        Mockito.verify(result).error(Mockito.eq("scan_failed"), anyString(), isNull())
    }

    @Test
    fun isAvailable_withoutActivity_isFalse() {
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        PolyscanScannerPlugin().onMethodCall(MethodCall("isAvailable", null), result)
        Mockito.verify(result).success(false)
    }
}
