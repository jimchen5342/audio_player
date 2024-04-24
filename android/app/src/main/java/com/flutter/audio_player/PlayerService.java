package com.flutter.audio_player;

import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.media.MediaPlayer;
import android.os.IBinder;
import android.util.Log;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class PlayerService extends Service {
    MediaPlayer mPlayer;
    HeadsetReceiver headsetReceiver;
    String path = "", TAG = "PlayerService";
    List<String> list;

    public PlayerService() {

    }

    @Override
    public void onCreate() {
        super.onCreate();

        IntentFilter filter = new IntentFilter(Intent.ACTION_HEADSET_PLUG);
        headsetReceiver = new HeadsetReceiver();
        registerReceiver(headsetReceiver, filter);

        try {
            mPlayer = new MediaPlayer();
            mPlayer.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
                @Override
                public void onCompletion(MediaPlayer mp) {
//                        Log.i(TAG, "onCompletion: " + format.format(new Date()) ) ;

                }
            });
            mPlayer.setLooping(false);

//            mPlayer.setDataSource(afd.getFileDescriptor(),
//                    afd.getStartOffset(), afd.getLength());
//            mPlayer.prepare();
           
//            mPlayer.start();
        } catch (Exception e) {
            mPlayer = null;
            e.printStackTrace();
//            Log.i(TAG, e.getMessage());
        } finally {

        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        mPlayer.release();
        mPlayer = null;

        unregisterReceiver(headsetReceiver);
    }


    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent.getExtras().getString("action");
        if(action.equals("initial")) {
            path = intent.getExtras().getString("path");

            String s1 = intent.getExtras().getString("list");
            String replace = s1.replace("[","").replace("]","");
            list = new ArrayList<String>(Arrays.asList(replace.split(",")));

            Log.i(TAG, path);
            Log.i(TAG, s1);
        }

        return START_REDELIVER_INTENT;
    }

    @Override
    public IBinder onBind(Intent intent) {
        // TODO: Return the communication channel to the service.
        throw new UnsupportedOperationException("Not yet implemented");
    }

    void play() {

//        mPlayer.setDataSource(afd.getFileDescriptor(),
//                    afd.getStartOffset(), afd.getLength());
//                mPlayer.prepare();
//            mPlayer.setLooping(false);
//            mPlayer.start();
    }

    void pause() {

    }

    void stop() {

    }

    void seek() {

    }

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