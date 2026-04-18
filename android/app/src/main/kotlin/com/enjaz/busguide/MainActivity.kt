package com.enjaz.busguide

import android.content.Intent
import com.enjaz.busguide.AuthApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var authApi: AuthApi

    companion object {
        const val RC_GOOGLE_SIGN_IN = 9001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        authApi = AuthApiImpl(this)
        AuthApi.setUp(flutterEngine.dartExecutor.binaryMessenger, authApi)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        (authApi as AuthApiImpl).onActivityResult(requestCode, resultCode, data)
    }
}
