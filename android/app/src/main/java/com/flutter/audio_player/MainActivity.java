package com.flutter.audio_player;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    public static EventChannel.EventSink eventSink;
    HeadsetReceiver headsetReceiver;

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

        IntentFilter filter = new IntentFilter(Intent.ACTION_HEADSET_PLUG);
        headsetReceiver = new HeadsetReceiver();
        registerReceiver(headsetReceiver, filter);

    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        unregisterReceiver(headsetReceiver);
    }

    MethodChannel.MethodCallHandler mMethodHandle = new MethodChannel.MethodCallHandler() {
        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {

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

    private class HeadsetReceiver extends BroadcastReceiver { // 耳機
        @Override public void onReceive(Context context, Intent intent) {

            String action = intent.getAction();
            if (action == null) {
                return;
            } else if (action.equals(Intent.ACTION_HEADSET_PLUG)) {
                int state = intent.getIntExtra("state", -1);
                switch (state) {
//                    case 0:
//                        if(MainActivity.eventSink != null)
//                            MainActivity.eventSink.success("unplugged");
//                        break;
//                    case 1:
//                        if(MainActivity.eventSink != null)
//                            MainActivity.eventSink.success("plugged");
//                        break;
//                    default:
//                        Log.d(TAG, "I have no idea what the headset state is");
                }
            }
        }
    }
}
