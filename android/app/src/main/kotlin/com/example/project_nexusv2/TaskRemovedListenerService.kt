package com.example.project_nexusv2

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
// This is the correct import for the service class
import id.flutter.flutter_background_service.BackgroundService

class TaskRemovedListenerService : Service() {

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("TaskRemovedListener", "Listener service started.")
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d("TaskRemovedListener", "Task removed by user. Restarting background service.")
        
        // This now correctly references the BackgroundService class from the plugin
        val serviceIntent = Intent(applicationContext, BackgroundService::class.java)
        applicationContext.startService(serviceIntent)
        
        super.onTaskRemoved(rootIntent)
    }
}