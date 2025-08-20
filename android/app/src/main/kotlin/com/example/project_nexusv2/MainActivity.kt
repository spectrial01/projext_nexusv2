package com.example.project_nexusv2

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import android.content.Intent // Import statement added

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Keep screen on when app is running
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)

        // Start the listener service to handle task removal
        val listenerIntent = Intent(this, TaskRemovedListenerService::class.java)
        startService(listenerIntent)
    }
}