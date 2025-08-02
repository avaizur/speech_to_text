package com.example.lectura;

import android.os.Bundle;
import android.util.Log;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.d("MainActivity", "MainActivity launched successfully");
        // If you plan to use MethodChannel or plugins, this is where to hook them
    }
}

