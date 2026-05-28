package dev.fluttercommunity.firebase_app_distribution;

import androidx.annotation.NonNull;
import com.google.firebase.appdistribution.FirebaseAppDistribution;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class FirebaseAppDistributionPlugin
    implements FlutterPlugin, MethodChannel.MethodCallHandler {
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    channel =
        new MethodChannel(
            binding.getBinaryMessenger(), "firebase_app_distribution_android");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    FirebaseAppDistribution appDistribution = FirebaseAppDistribution.getInstance();
    switch (call.method) {
      case "updateIfNewReleaseAvailable":
        appDistribution.updateIfNewReleaseAvailable();
        result.success(null);
        break;
      case "isNewReleaseAvailable":
        appDistribution
            .checkForNewRelease()
            .addOnSuccessListener(release -> result.success(release != null))
            .addOnFailureListener(
                error ->
                    result.error(
                        "CHECK_FAILED",
                        "Can not check for new release",
                        "checkForNewRelease() failed with " + error));
        break;
      case "isTesterSignedIn":
        result.success(appDistribution.isTesterSignedIn());
        break;
      case "signInTester":
        appDistribution
            .signInTester()
            .addOnSuccessListener(unused -> result.success(true))
            .addOnFailureListener(
                error ->
                    result.error(
                        "SIGN_IN_TESTER_FAILED",
                        "Can not sign in tester",
                        "signInTester() failed with " + error));
        break;
      case "signOutTester":
        appDistribution.signOutTester();
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    channel = null;
  }
}
