package com.flutter.audio_player;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;

import androidx.annotation.NonNull;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    public static EventChannel.EventSink eventSink;
    String TAG = "Player-Main";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor(),
                "com.flutter/MethodChannel")
                .setMethodCallHandler(mMethodHandle);

        new EventChannel(flutterEngine.getDartExecutor(),
                "com.flutter/EventChannel")
                .setStreamHandler(mEnventHandle);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        MainActivity.eventSink = null;
    }

    MethodChannel.MethodCallHandler mMethodHandle = new MethodChannel.MethodCallHandler() {
        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            if(call.method.equals("initial")) {
                Intent intent = new Intent();
                intent.putExtra("action", "initial");
                String path = call.argument("path");
                intent.putExtra("path", path);

                String list = call.argument("list");
                intent.putExtra("list", list);
                // Log.i(TAG, path);
                // Log.i(TAG, list);
                intent.setClass(MainActivity.this, PlayerService.class);
                startService(intent);
                result.success("OK");
            }
            else if(call.method.equals("information")) {
                Intent intent = new Intent();
                intent.putExtra("action", "information");
                intent.setClass(MainActivity.this, PlayerService.class);
                startService(intent);
                result.success("OK");
            }
            else if(call.method.equals("play")) {
                Intent intent = new Intent();
                intent.putExtra("action", "play");

                String song = call.argument("song");
                intent.putExtra("song", song);
                // int position = all.argument("position");
                // intent.putExtra("position", position);

                intent.setClass(MainActivity.this, PlayerService.class);
                startService(intent);
                result.success("OK");
            }
            else if(call.method.equals("seek")) {
                Intent intent = new Intent();
                intent.putExtra("action", "seek");
                int position = call.argument("position");
                intent.putExtra("position", position);
                intent.setClass(MainActivity.this, PlayerService.class);
                startService(intent);

                result.success("OK");
            }
            else if(call.method.equals("pause")) {
                Intent intent = new Intent();
                intent.putExtra("action", "pause");
                intent.setClass(MainActivity.this, PlayerService.class);
                startService(intent);
                result.success("pause");
            }
            else if(call.method.equals("stop")) {
                Intent intent = new Intent();
                intent.putExtra("action", "stop");
                intent.setClass(MainActivity.this, PlayerService.class);
                startService(intent);
                result.success("stop");
            } else {
                result.notImplemented();
            }

        }
    };
    EventChannel.StreamHandler mEnventHandle = new EventChannel.StreamHandler() {
        @Override
        public void onListen(Object o, EventChannel.EventSink eventSink) {
            MainActivity.eventSink = eventSink;
        }

        @Override
        public void onCancel(Object o) {
        }
    };

}
