package com.example.phr_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import android.content.Intent
import android.os.Bundle

class MainActivity : FlutterFragmentActivity() {
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Ensure proper setup for Health Connect permissions
        // The Flutter health plugin will handle the actual permission requests
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle Health Connect permission rationale if needed
        if (intent?.action == "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE") {
            // This activity can be used to show permission rationale
            // The health plugin will handle the actual permission flow
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Health Connect permission results will be handled by the health plugin
    }
}
