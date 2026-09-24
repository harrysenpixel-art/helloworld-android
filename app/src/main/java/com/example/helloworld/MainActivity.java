package com.example.helloworld;

import android.app.Activity;
import android.net.Uri;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.util.Locale;

public class MainActivity extends Activity {

    private int count = 0;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private boolean pendingVoiceGreeting = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        TextView hello = new TextView(this);
        hello.setText("Hello World \uD83D\uDC4B");
        hello.setTextSize(34);
        hello.setGravity(Gravity.CENTER);

        TextView counter = new TextView(this);
        counter.setText("你点了 0 次");
        counter.setTextSize(18);
        counter.setGravity(Gravity.CENTER);
        counter.setPadding(0, 24, 0, 24);

        Button button = new Button(this);
        button.setText("点我试试");
        button.setOnClickListener(v -> {
            count++;
            counter.setText("你点了 " + count + " 次");
            if (count == 10) {
                Toast.makeText(MainActivity.this, "十全十美！", Toast.LENGTH_SHORT).show();
            }
        });

        Button speakButton = new Button(this);
        speakButton.setText("\uD83D\uDD0A 试听语音播报");
        speakButton.setOnClickListener(v -> speakGreeting());

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setPadding(48, 48, 48, 48);
        layout.addView(hello);
        layout.addView(counter);
        layout.addView(button);
        layout.addView(speakButton);

        setContentView(layout);

        // 初始化语音播报(TTS),无需任何权限
        tts = new TextToSpeech(this, status -> {
            if (status == TextToSpeech.SUCCESS) {
                int result = tts.setLanguage(Locale.CHINESE);
                if (result != TextToSpeech.LANG_MISSING_DATA
                        && result != TextToSpeech.LANG_NOT_SUPPORTED) {
                    ttsReady = true;
                    if (pendingVoiceGreeting) {
                        pendingVoiceGreeting = false;
                        speakGreeting();
                    }
                }
            }
        });

        // 如果是被语音指令 / deep link 唤起的,自动播报一句,证明"联动上了"
        if (isVoiceLaunch()) {
            pendingVoiceGreeting = true;
            Toast.makeText(this, "通过语音指令启动", Toast.LENGTH_SHORT).show();
        }
    }

    /** 判断是否来自 App Actions 语音指令的 deep link */
    private boolean isVoiceLaunch() {
        if (getIntent() == null) {
            return false;
        }
        Uri data = getIntent().getData();
        if (data != null && "helloworld.example.com".equals(data.getHost())) {
            return true;
        }
        return getIntent().hasExtra("feature")
                || getIntent().hasExtra("greeting");
    }

    private void speakGreeting() {
        if (!ttsReady || tts == null) {
            Toast.makeText(this, "语音引擎还在准备,稍候再试", Toast.LENGTH_SHORT).show();
            return;
        }
        tts.speak("你好!Hello World 已通过语音启动,联动成功!",
                TextToSpeech.QUEUE_FLUSH, null, "voice_greeting");
    }

    @Override
    protected void onDestroy() {
        if (tts != null) {
            tts.stop();
            tts.shutdown();
        }
        super.onDestroy();
    }
}
