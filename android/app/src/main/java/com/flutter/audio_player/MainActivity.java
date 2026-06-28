package com.flutter.audio_player;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.media.MediaPlayer;
import android.os.Bundle;

import androidx.annotation.NonNull;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;
import com.ryanheise.audioservice.AudioServiceActivity;

public class MainActivity extends AudioServiceActivity { // FlutterActivity {
    public static EventChannel.EventSink eventSink;
    String TAG = "Player-Main";
    private MediaPlayer mediaPlayer;

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
        releaseMediaPlayer();
    }

    private void releaseMediaPlayer() {
        if (mediaPlayer != null) {
            if (mediaPlayer.isPlaying()) {
                mediaPlayer.stop();
            }
            mediaPlayer.release();
            mediaPlayer = null;
        }
    }

    private void playBeepFromAssets(@NonNull MethodChannel.Result result) {
        releaseMediaPlayer();
        try {
            AssetManager assetManager = getAssets();
            AssetFileDescriptor afd = assetManager.openFd("beep.mp3");
            mediaPlayer = new MediaPlayer();
            mediaPlayer.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
            afd.close();
            mediaPlayer.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
                @Override
                public void onCompletion(MediaPlayer mp) {
                    releaseMediaPlayer();
                    result.success("OK");
                }
            });
            mediaPlayer.prepare();
            mediaPlayer.start();
            
        } catch (Exception e) {
            Log.e(TAG, "Failed to play beep.mp3", e);
            releaseMediaPlayer();
            result.error("PLAY_FAILED", "Unable to play beep.mp3", e.getMessage());
        }
    }

    MethodChannel.MethodCallHandler mMethodHandle = new MethodChannel.MethodCallHandler() {
        @Override
        public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
            if (call.method.equals("beep")) {
                playBeepFromAssets(result);
            } else {
                result.notImplemented();
            }
        }
    };
    EventChannel.StreamHandler mEnventHandle = new EventChannel.StreamHandler() {
        @Override
        public void onListen(Object o, EventChannel.EventSink eventSink) {
            // MainActivity.eventSink = eventSink;
        }

        @Override
        public void onCancel(Object o) {
        }
    };

}
