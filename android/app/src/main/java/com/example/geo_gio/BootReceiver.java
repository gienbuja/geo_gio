package com.example.geo_gio;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.widget.Toast;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent.getAction().equals(Intent.ACTION_BOOT_COMPLETED)) {
            Toast.makeText(context, "Iniciando...", Toast.LENGTH_SHORT).show();
            // Aquí puedes agregar el código que deseas ejecutar al recibir el evento de BOOT_COMPLETED
        }
    }
}