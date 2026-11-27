// Panel output helper: select / show the media output the way the system output switcher does for a
// device route (AudioManager preferred device for the media strategy). Run as root via app_process.
//   PanelRoute selected | select <ip>|speaker
import android.app.ActivityThread;
import android.content.Context;
import android.media.AudioDeviceAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.media.audiopolicy.AudioProductStrategy;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioTrack;
import android.os.Looper;
import java.util.List;

public class PanelRoute {
    static AudioProductStrategy media() {
        AudioAttributes a = new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build();
        for (AudioProductStrategy s : AudioManager.getAudioProductStrategies())
            if (s.supportsAudioAttributes(a)) return s;
        return null;
    }
    public static void main(String[] args) throws Exception {
        Looper.prepareMainLooper();
        Context ctx = ActivityThread.systemMain().getSystemContext();
        AudioManager am = ctx.getSystemService(AudioManager.class);
        AudioProductStrategy s = media();
        if (s == null) { System.err.println("no media strategy"); System.exit(3); }
        String cmd = args.length > 0 ? args[0] : "selected";
        if (cmd.equals("select") && args.length > 1) {
            if (args[1].equals("speaker")) am.removePreferredDeviceForStrategy(s);
            else am.setPreferredDeviceForStrategy(s, new AudioDeviceAttributes(
                    AudioDeviceAttributes.ROLE_OUTPUT, AudioDeviceInfo.TYPE_BUS, args[1]));
            Thread.sleep(1000);
        }
        if (cmd.equals("silence")) {  // play pure digital silence on the media output for N seconds
            int secs = args.length > 1 ? Integer.parseInt(args[1]) : 8;
            int rate = 48000; int bytes = rate * 4;
            AudioTrack t = new AudioTrack.Builder()
                .setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setAudioFormat(new AudioFormat.Builder().setSampleRate(rate)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO).build())
                .setBufferSizeInBytes(bytes).setTransferMode(AudioTrack.MODE_STREAM).build();
            byte[] zero = new byte[bytes / 4];
            t.play();
            long end = System.currentTimeMillis() + secs * 1000L;
            String routed = null;
            while (System.currentTimeMillis() < end) {
                t.write(zero, 0, zero.length, AudioTrack.WRITE_NON_BLOCKING);
                if (routed == null && t.getRoutedDevice() != null)
                    routed = t.getRoutedDevice().getType() + " " + t.getRoutedDevice().getAddress();
                Thread.sleep(20);
            }
            System.out.println("silence played " + secs + "s to device " + routed);
            t.pause(); t.flush(); t.release();
            System.exit(0);  // do not linger on the audio threads
        }
        AudioAttributes a = new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build();
        List<AudioDeviceAttributes> d = am.getDevicesForAttributes(a);
        for (AudioDeviceAttributes x : d) System.out.println("media -> type=" + x.getType() + " address=" + x.getAddress());
        System.exit(0);
    }
}
