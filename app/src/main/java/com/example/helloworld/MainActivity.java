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

    /** 外部指令入口:Tasker / am / 语音桥接发送此 action 即可触发播报 */
    public static final String ACTION_SPEAK = "com.example.helloworld.action.SPEAK";
    public static final String EXTRA_TEXT = "extra_text";

    /** 打开 App 就自动播报一句(无需 Tasker、无需点按钮) */
    private static final String AUTO_GREETING = "你好!Hello World 已打开!";

    private int count = 0;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private String pendingSpeakText = null;
    private String pendingGreetingText = null;

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
                    if (pendingSpeakText != null) {
                        String text = pendingSpeakText;
                        pendingSpeakText = null;
                        speakText(text);
                    } else if (pendingGreetingText != null) {
                        String text = pendingGreetingText;
                        pendingGreetingText = null;
                        speakText(text);
                    }
                }
            }
        });

        boolean handled = handleIncomingIntent(getIntent());
        // 全新打开(含"Hey Google,打开 Hello World"):TTS 就绪后自动播报一句
        if (savedInstanceState == null && !handled) {
            pendingGreetingText = AUTO_GREETING;
        }
    }

    @Override
    protected void onNewIntent(android.content.Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        boolean handled = handleIncomingIntent(intent);
        // 已在运行时被再次打开(例如语音再次唤起):也自动播报一句
        if (!handled) {
            if (ttsReady) {
                speakText(AUTO_GREETING);
            } else {
                pendingGreetingText = AUTO_GREETING;
            }
        }
    }

    /**
     * 统一处理外部来的"让它说话"请求:deep link 语音唤起 / SPEAK 指令
     * @return true 表示已经安排了播报,调用方无需再自动问候
     */
    private boolean handleIncomingIntent(android.content.Intent intent) {
        if (intent == null) {
            return false;
        }
        // Tasker / am 发来的播报指令
        if (ACTION_SPEAK.equals(intent.getAction())) {
            String text = intent.getStringExtra(EXTRA_TEXT);
            if (text == null || text.isEmpty()) {
                text = "你好!Hello World 已通过语音指令启动,联动成功!";
            }
            if (ttsReady) {
                speakText(text);
            } else {
                pendingSpeakText = text;
            }
            Toast.makeText(this, "收到播报指令", Toast.LENGTH_SHORT).show();
            return true;
        }
        // 如果是被语音指令 / deep link 唤起的,自动播报一句,证明"联动上了"
        if (isVoiceLaunch()) {
            pendingGreetingText = "你好!Hello World 已通过语音启动,联动成功!";
            Toast.makeText(this, "通过语音指令启动", Toast.LENGTH_SHORT).show();
            return true;
        }
        return false;
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
        speakText("你好!Hello World 已通过语音启动,联动成功!");
    }

    private void speakText(String text) {
        if (!ttsReady || tts == null) {
            Toast.makeText(this, "语音引擎还在准备,稍候再试", Toast.LENGTH_SHORT).show();
            return;
        }
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "voice_greeting");
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
