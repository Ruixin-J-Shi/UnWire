package com.example.P2PChatApp

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import android.util.Log

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "MainActivity started")
    }
}
