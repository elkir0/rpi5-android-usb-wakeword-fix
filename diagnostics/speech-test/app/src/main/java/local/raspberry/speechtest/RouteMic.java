// SPDX-License-Identifier: Apache-2.0
package local.raspberry.speechtest;

import android.content.Context;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.os.Looper;
import java.lang.reflect.Method;
import java.lang.reflect.Constructor;
import java.util.Collections;

/** One-shot root/app_process diagnostic to prefer the USB mic at runtime. */
public final class RouteMic {
    public static void main(String[] args) throws Exception {
        Looper.prepareMainLooper();
        Class<?> activityThread = Class.forName("android.app.ActivityThread");
        Object thread = activityThread.getDeclaredMethod("systemMain").invoke(null);
        Context context = (Context) activityThread.getDeclaredMethod("getSystemContext").invoke(thread);
        AudioManager audio = context.getSystemService(AudioManager.class);

        AudioDeviceInfo usb = null;
        AudioDeviceInfo builtIn = null;
        for (AudioDeviceInfo device : audio.getDevices(AudioManager.GET_DEVICES_INPUTS)) {
            System.out.println("input id=" + device.getId() + " type=" + device.getType()
                    + " address=" + device.getAddress() + " name=" + device.getProductName());
            if (device.isSource() && (device.getType() == AudioDeviceInfo.TYPE_USB_DEVICE
                    || device.getType() == AudioDeviceInfo.TYPE_USB_HEADSET)) {
                usb = device;
            }
            if (device.isSource() && device.getType() == AudioDeviceInfo.TYPE_BUILTIN_MIC) {
                builtIn = device;
            }
        }
        if (usb == null) throw new IllegalStateException("No USB input device");

        Class<?> audioSystem = Class.forName("android.media.AudioSystem");
        Class<?> attributes = Class.forName("android.media.AudioDeviceAttributes");
        Constructor<?> fromDevice = attributes.getDeclaredConstructor(AudioDeviceInfo.class);
        Object usbAttributes = fromDevice.newInstance(usb);
        Method setRole = audioSystem.getDeclaredMethod(
                "setDevicesRoleForCapturePreset", int.class, int.class, java.util.List.class);
        int[] presets = {0, 1, 6, 1999}; // DEFAULT, MIC, VOICE_RECOGNITION, HOTWORD
        for (int preset : presets) {
            Object result = setRole.invoke(null, preset, 1, Collections.singletonList(usbAttributes));
            System.out.println("preset=" + preset + " preferred USB result=" + result);
        }
        if (builtIn != null) {
            Object builtInAttributes = fromDevice.newInstance(builtIn);
            Method setConnection = audioSystem.getDeclaredMethod(
                    "setDeviceConnectionState", attributes, int.class, int.class);
            Object result = setConnection.invoke(null, builtInAttributes, 0, 0);
            System.out.println("built-in mic unavailable result=" + result);
        }
        System.exit(0);
    }
}
