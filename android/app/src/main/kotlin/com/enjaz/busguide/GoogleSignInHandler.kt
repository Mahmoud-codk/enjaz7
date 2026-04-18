package com.enjaz.busguide

import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.enjaz.busguide.R

class GoogleSignInHandler(private val activity: Activity) {
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
    private val googleSignInClient: GoogleSignInClient
    private var pendingCallback: ((Result<PigeonUserDetails?>) -> Unit)? = null

    init {
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(activity.getString(R.string.default_web_client_id)) // From google-services.json
            .requestEmail()
            .build()
        googleSignInClient = GoogleSignIn.getClient(activity, gso)
    }

    fun signIn(callback: (Result<PigeonUserDetails?>) -> Unit) {
        pendingCallback = callback
        val signInIntent = googleSignInClient.signInIntent
        activity.startActivityForResult(signInIntent, MainActivity.RC_GOOGLE_SIGN_IN)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == MainActivity.RC_GOOGLE_SIGN_IN) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            handleSignInResult(task)
        }
    }

    private fun handleSignInResult(completedTask: com.google.android.gms.tasks.Task<GoogleSignInAccount>) {
        try {
            val account = completedTask.getResult(ApiException::class.java)
            firebaseAuthWithGoogle(account.idToken!!)
        } catch (e: ApiException) {
            pendingCallback?.invoke(Result.success(null))
            pendingCallback = null
        }
    }

    private fun firebaseAuthWithGoogle(idToken: String) {
        val credential = GoogleAuthProvider.getCredential(idToken, null)
        auth.signInWithCredential(credential)
            .addOnCompleteListener(activity) { task ->
                if (task.isSuccessful) {
                    val user = auth.currentUser
                    val pigeonUser = PigeonUserDetails(
                        userId = user?.uid,
                        email = user?.email,
                        name = user?.displayName,
                        photoUrl = user?.photoUrl?.toString(),
                        provider = "google"
                    )
                    pendingCallback?.invoke(Result.success(pigeonUser))
                } else {
                    pendingCallback?.invoke(Result.success(null))
                }
                pendingCallback = null
            }
    }

    fun signOut() {
        googleSignInClient.signOut()
        auth.signOut()
    }
}
