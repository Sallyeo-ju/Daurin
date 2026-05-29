# TODO

## Fix issues: Register red screen + bottom overflow

1. Update `client/lib/RegisterPage.dart`
   - Fix navigation/pop timing after register/login/pin dialogs to prevent red error overlay.
   - Adjust layout/scroll strategy to eliminate “BOTTOM OVERFLOWED BY … PIXELS”.
2. Run Flutter checks
   - `flutter analyze`
   - `flutter test` (if available)
3. Manual verification
   - Register flow including auto-login and PIN prompt.
   - Test on small screen / with keyboard open to confirm overflow is gone.

