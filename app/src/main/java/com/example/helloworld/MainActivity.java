package com.example.helloworld;

import android.app.Activity;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

public class MainActivity extends Activity {

    private int count = 0;

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

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setPadding(48, 48, 48, 48);
        layout.addView(hello);
        layout.addView(counter);
        layout.addView(button);

        setContentView(layout);
    }
}
