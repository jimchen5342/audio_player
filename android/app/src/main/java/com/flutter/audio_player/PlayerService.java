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

import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class PlayerService extends Service {
    MediaPlayer mPlayer;
    HeadsetReceiver headsetReceiver;
    String path = "", song = "", TAG = "Player-Service";
    List<String> list;

    public PlayerService() {

    }

    @Override
    public void onCreate() {
        super.onCreate();

        IntentFilter filter = new IntentFilter(Intent.ACTION_HEADSET_PLUG);
        headsetReceiver = new HeadsetReceiver();
        registerReceiver(headsetReceiver, filter);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if(mPlayer != null) {
            mPlayer.release();
            mPlayer = null;            
        }
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
            // Log.i(TAG, path);
            // Log.i(TAG, s1);
        } else if(action.equals("play")) {
            String s1 = intent.getExtras().getString("song");
            if(! s1.equals(song)) {
                if(mPlayer != null) {
                    mPlayer.stop();
                    mPlayer.release();
                    mPlayer = null;
                }
                song = s1;
                play();
            }
        } else if(action.equals("seek")) {
            int position = intent.getExtras().getInt("position");
            seek(position);
        } else if(action.equals("pause")) {

        } else if(action.equals("stop")) {
            stop();
        } else if(action.equals("information")) { // 來自 home.dart, app 剛啟動
            if(MainActivity.eventSink != null) {
                try{
                    JSONObject jsonObject = new JSONObject();
                    jsonObject.put("action", action);
                    jsonObject.put("path", path);
                    jsonObject.put("song", song);
                    jsonObject.put("position", mPlayer.getCurrentPosition() * 0.001);
                    MainActivity.eventSink.success(jsonObject.toString());
                }
                catch(JSONException e) {
                    e.printStackTrace();
                }
            }
            if(song.length() == 0)
                stopSelf();
        }
        return START_STICKY;
    }


    @Override
    public IBinder onBind(Intent intent) {
        throw new UnsupportedOperationException("Not yet implemented");
    }

    void play() {
        try {
            mPlayer = new MediaPlayer();
            mPlayer.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
                @Override
                public void onCompletion(MediaPlayer mp) {
                    //    Log.i(TAG, "onCompletion: " + format.format(new Date()) ) ;
                }
            });
            mPlayer.setLooping(false);
            mPlayer.setDataSource(path + "/" + song);
            mPlayer.prepare();
            mPlayer.setLooping(false);
            mPlayer.start();
        } catch (Exception e) {
            Log.i(TAG, e.getMessage());
        }
    }

    void pause() {
        if(mPlayer != null) {
            mPlayer.pause();
        }
    }

    void stop() {
        if(mPlayer != null) {
            mPlayer.stop();
        }
        this.stopSelf();
    }

    void seek(int position) {
        if(mPlayer != null) {
            mPlayer.seekTo(position * 1000);
        }
    }

    private class HeadsetReceiver extends BroadcastReceiver { // 耳機
        @Override public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            if (action == null) {
                return;
            } else if (action.equals(Intent.ACTION_HEADSET_PLUG)) {
                int state = intent.getIntExtra("state", -1);
                switch (state) {
                    case 0:
                        if(MainActivity.eventSink != null)
                            MainActivity.eventSink.success("unplugged");
                        break;
                    case 1:
                        if(MainActivity.eventSink != null)
                            MainActivity.eventSink.success("plugged");
                        break;
                    default:
                        Log.d(TAG, "I have no idea what the headset state is");
                }
            }
        }
    }
}