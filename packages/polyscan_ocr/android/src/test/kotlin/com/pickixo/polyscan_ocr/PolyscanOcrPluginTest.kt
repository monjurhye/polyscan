package com.pickixo.polyscan_ocr

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.ArgumentMatchers.anyString
import org.mockito.ArgumentMatchers.isNull
import org.mockito.Mockito
import kotlin.test.Test

internal class PolyscanOcrPluginTest {
    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        PolyscanOcrPlugin().onMethodCall(MethodCall("noSuchMethod", null), mockResult)
        Mockito.verify(mockResult).notImplemented()
    }

    @Test
    fun onMethodCall_recognizeWithoutArgs_failsWithBadArgs() {
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        PolyscanOcrPlugin().onMethodCall(MethodCall("recognize", null), mockResult)
        Mockito.verify(mockResult).error(Mockito.eq("bad_args"), anyString(), isNull())
    }
}
