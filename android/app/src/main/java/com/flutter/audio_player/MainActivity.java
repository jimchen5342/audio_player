package com.flutter.audio_player;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    public static EventChannel.EventSink eventSink;

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
    }

    MethodChannel.MethodCallHandler mMethodHandle = new MethodChannel.MethodCallHandler() {
        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            if(call.method.equals("initial")) {
                Intent intent = new Intent();
                intent.putExtra("action", "initial");
                String path = call.argument("path");
                intent.putExtra("path", path);

                print(path);

                String list = call.argument("list");
                intent.putExtra("list", list);

                intent.setClass(MainActivity.this, PlayerService.class);
                startService(intent);
            } else if(call.method.equals("play")) {

//                mode = "play";
//                title = call.argument("title");
//                author = call.argument("author");
//                position = call.argument("position");
//                showNotification();


                Intent intent = new Intent();
                intent.putExtra("action", "play");
                intent.putExtra("playList", "");
                intent.putExtra("fileName", "");
                intent.putExtra("positionn", 0);

                intent.setClass(MainActivity.this, PlayerService.class);
                startService(intent);
            } else if(call.method.equals("pause")) {
//                mode = "pause";
//                showNotification();
            } else if(call.method.equals("stop")) {
//                mode = "stop";
//                mNM.cancel(1);
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
