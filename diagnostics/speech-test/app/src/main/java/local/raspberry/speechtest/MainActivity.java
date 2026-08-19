// SPDX-License-Identifier: Apache-2.0
package local.raspberry.speechtest;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.speech.RecognizerIntent;
import android.widget.TextView;
import java.util.ArrayList;

public class MainActivity extends Activity {
    private TextView status;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        status = new TextView(this); status.setTextSize(28); status.setPadding(40,40,40,40);
        status.setText("Initialisation…"); setContentView(status);
        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) requestPermissions(new String[]{android.Manifest.permission.RECORD_AUDIO}, 9); else listen();
    }
    @Override public void onRequestPermissionsResult(int r, String[] p, int[] g) { super.onRequestPermissionsResult(r,p,g); if (r == 9 && g.length > 0 && g[0] == PackageManager.PERMISSION_GRANTED) listen(); else status.setText("ERREUR permission micro"); }
    private void listen() {
        status.setText("Dites : test microphone bonjour");
        Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "fr-FR");
        i.putExtra(RecognizerIntent.EXTRA_PROMPT, "Dites : test microphone bonjour");
        startActivityForResult(i, 42);
    }
    @Override protected void onActivityResult(int req, int result, Intent data) {
        super.onActivityResult(req,result,data);
        if (req != 42) return;
        ArrayList<String> words = data == null ? null : data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
        status.setText("resultCode=" + result + "\nRésultat : " + (words == null ? "aucun" : words.toString()));
    }
}
