package com.enjaz.busguide

import android.app.Activity
import android.content.Intent
import kotlin.Result
import com.enjaz.busguide.AuthApi
import com.enjaz.busguide.PigeonAuthResult

class AuthApiImpl(private val activity: Activity) : AuthApi {
    private val googleSignInHandler = GoogleSignInHandler(activity)
    // private val facebookSignInHandler = FacebookSignInHandler(activity)

    override fun loginWithGoogle(callback: (Result<PigeonUserDetails?>) -> Unit) {
        googleSignInHandler.signIn(callback)
    }

    // Facebook login disabled
    // override fun loginWithFacebook(callback: (Result<PigeonUserDetails?>) -> Unit) {
    //     facebookSignInHandler.signIn(callback)
    // }

    override fun logout(callback: (Result<PigeonAuthResult>) -> Unit) {
        googleSignInHandler.signOut()
        // facebookSignInHandler.signOut()
        // Assuming logout always succeeds
        val result = PigeonAuthResult(success = true, user = null, error = null)
        callback(Result.success(result))
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        googleSignInHandler.onActivityResult(requestCode, resultCode, data)
        // facebookSignInHandler.onActivityResult(requestCode, resultCode, data)
    }
}
