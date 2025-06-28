package com.example.hundlename;

import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.talkone.app/ai_filter";
    private AIFilterService aiFilterService;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        aiFilterService = new AIFilterService();
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    switch (call.method) {
                        case "initializeAIFilter":
                            boolean initialized = aiFilterService.initialize();
                            result.success(initialized);
                            break;
                        case "enableAIFilter":
                            boolean enabled = call.argument("enabled");
                            aiFilterService.setEnabled(enabled);
                            result.success(null);
                            break;
                        case "setFilterParams":
                            int threshold1 = call.argument("threshold1");
                            int threshold2 = call.argument("threshold2");
                            boolean colorful = call.argument("colorful");
                            aiFilterService.setFilterParams(threshold1, threshold2, colorful);
                            result.success(null);
                            break;
                        case "releaseAIFilter":
                            aiFilterService.release();
                            result.success(null);
                            break;
                        default:
                            result.notImplemented();
                            break;
                    }
                }
            );
    }
}