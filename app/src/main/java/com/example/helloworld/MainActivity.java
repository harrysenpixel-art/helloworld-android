package com.example.helloworld;

import android.app.Activity;
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

    /** Tasker 联动:App 打开时通知 Tasker 运行此任务,具体做什么由 Tasker 任务决定(高度可定制) */
    private static final String TASKER_TASK_NAME = "HelloWorld联动";
    private static final String TASKER_PACKAGE = "net.dinglisch.android.taskerm";
    private static final String ACTION_RUN_TASKER_TASK = "net.dinglisch.android.tasker.ACTION_TASK";

    private int count = 0;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private String pendingSpeakText = null;

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

        // v1.5 诊断用:手动触发 Tasker 通知,验证广播通道本身是否通
        Button taskerButton = new Button(this);
        taskerButton.setText("\uD83D\uDCE1 测试通知 Tasker");
        taskerButton.setOnClickListener(v -> notifyTasker());

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setPadding(48, 48, 48, 48);
        layout.addView(hello);
        layout.addView(counter);
        layout.addView(button);
        layout.addView(speakButton);
        layout.addView(taskerButton);

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
                    }
                }
            }
        });

        boolean isSpeakLaunch = ACTION_SPEAK.equals(getIntent().getAction());
        handleIncomingIntent(getIntent());
        if (savedInstanceState == null && !isSpeakLaunch) {
            // 全新打开(含"Hey Google,打开 Hello World"):通知 Tasker,由"HelloWorld联动"任务决定做什么
            notifyTasker();
        }
    }

    @Override
    protected void onNewIntent(android.content.Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        boolean handled = handleIncomingIntent(intent);
        // 非 SPEAK 的再次打开也通知 Tasker;SPEAK 是 Tasker 发来的,不回通知,避免循环
        if (!handled) {
            notifyTasker();
        }
    }

    /**
     * 处理 Tasker 发来的 SPEAK 播报指令
     * @return true 表示是 SPEAK 指令(调用方不要再通知 Tasker,避免循环)
     */
    private boolean handleIncomingIntent(android.content.Intent intent) {
        if (intent == null) {
            return false;
        }
        // Tasker 发来的播报指令
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
        return false;
    }

    /** 通知 Tasker 运行联动任务(显式广播,无需任何权限,不依赖后台检测) */
    private void notifyTasker() {
        try {
            android.content.Intent i = new android.content.Intent(ACTION_RUN_TASKER_TASK);
            i.setPackage(TASKER_PACKAGE);
            i.putExtra("task_name", TASKER_TASK_NAME);
            sendBroadcast(i);
            // v1.5 诊断用:让用户亲眼看到广播已发出
            Toast.makeText(this, "已发送广播通知 Tasker", Toast.LENGTH_SHORT).show();
        } catch (Exception ignored) {
        }
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
