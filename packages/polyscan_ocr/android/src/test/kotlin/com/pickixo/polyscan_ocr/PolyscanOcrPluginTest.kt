package com.pickixo.polyscan_ocr

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class PolyscanOcrPluginTest {
    @Test
    fun onMethodCall_isNotImplementedYet() {
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        PolyscanOcrPlugin().onMethodCall(MethodCall("recognize", null), mockResult)
        Mockito.verify(mockResult).notImplemented()
    }
}
