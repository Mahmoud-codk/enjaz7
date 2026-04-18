package com.enjaz.busguide

// ⚠️ فيسبوك معطل - تم حذف جميع التكاملات
// This file is no longer in use - Facebook integration has been disabled
/*
import android.app.Activity
import android.content.Intent
import com.facebook.AccessToken
import com.facebook.CallbackManager
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.login.LoginManager
import com.facebook.login.LoginResult
import com.google.firebase.auth.FacebookAuthProvider
import com.google.firebase.auth.FirebaseAuth
import kotlin.Result
import com.enjaz.busguide.PigeonAuthResult

class FacebookSignInHandler(private val activity: Activity) {
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
    private val callbackManager: CallbackManager = CallbackManager.Factory.create()
    private var pendingCallback: ((Result<PigeonUserDetails?>) -> Unit)? = null

    init {
        LoginManager.getInstance().registerCallback(callbackManager, object : FacebookCallback<LoginResult> {
            override fun onSuccess(loginResult: LoginResult) {
                handleFacebookAccessToken(loginResult.accessToken)
            }

            override fun onCancel() {
                pendingCallback?.invoke(Result.success(null))
                pendingCallback = null
            }

            override fun onError(error: FacebookException) {
                pendingCallback?.invoke(Result.success(null))
                pendingCallback = null
            }
        })
    }

    fun signIn(callback: (Result<PigeonUserDetails?>) -> Unit) {
        pendingCallback = callback
        LoginManager.getInstance().logInWithReadPermissions(activity, listOf("email", "public_profile"))
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        callbackManager.onActivityResult(requestCode, resultCode, data)
    }

    private fun handleFacebookAccessToken(token: AccessToken) {
        val credential = FacebookAuthProvider.getCredential(token.token)
        auth.signInWithCredential(credential)
            .addOnCompleteListener(activity) { task ->
                if (task.isSuccessful) {
                    val user = auth.currentUser
                    val pigeonUser = PigeonUserDetails(
                        userId = user?.uid,
                        email = user?.email,
                        name = user?.displayName,
                        photoUrl = user?.photoUrl?.toString(),
                        provider = "facebook"
                    )
                    pendingCallback?.invoke(Result.success(pigeonUser))
                } else {
                    pendingCallback?.invoke(Result.success(null))
                }
                pendingCallback = null
            }
    }

    fun signOut() {
        LoginManager.getInstance().logOut()
        auth.signOut()
    }
}
*/
