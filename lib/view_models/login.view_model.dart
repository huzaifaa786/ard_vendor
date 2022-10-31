import 'package:cool_alert/cool_alert.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuodz/constants/api.dart';
import 'package:fuodz/constants/app_routes.dart';
import 'package:fuodz/constants/app_strings.dart';
import 'package:fuodz/models/api_response.dart';
import 'package:fuodz/requests/auth.request.dart';
import 'package:fuodz/services/auth.service.dart';
import 'package:fuodz/traits/qrcode_scanner.trait.dart';
import 'package:fuodz/widgets/bottomsheets/account_verification_entry.dart';
import 'package:localize_and_translate/localize_and_translate.dart';
import 'base.view_model.dart';
import 'package:velocity_x/velocity_x.dart';

class LoginViewModel extends MyBaseViewModel with QrcodeScannerTrait {
  //the textediting controllers
  TextEditingController phoneTEC = new TextEditingController();
  TextEditingController emailTEC = new TextEditingController();
  TextEditingController passwordTEC = new TextEditingController();

  //
  AuthRequest _authRequest = AuthRequest();
  Country selectedCountry;
  String accountPhoneNumber;
  bool otpLogin = false;
  LoginViewModel(BuildContext context) {
    this.viewContext = context;
  }

  void initialise() {
    //
    emailTEC.text = kReleaseMode ? "" : "manager@demo.com";
    passwordTEC.text = kReleaseMode ? "" : "password";
    try {
      this.selectedCountry = Country.parse(AppStrings.countryCode
          .toUpperCase()
          .replaceAll("AUTO,", "")
          .split(",")[0]);
    } catch (error) {
      this.selectedCountry = Country.parse("gh");
    }
  }

  void processLogin() async {
    // Validate returns true if the form is valid, otherwise false.
    if (formKey.currentState.validate()) {
      //

      setBusy(true);

      final apiResponse = await _authRequest.loginRequest(
        email: emailTEC.text,
        password: passwordTEC.text,
      );
      await handleDeviceLogin(apiResponse);

      setBusy(false);
    }
  }

  showCountryDialPicker() {
    showCountryPicker(
      context: viewContext,
      showPhoneCode: true,
      onSelect: countryCodeSelected,
    );
  }

  countryCodeSelected(Country country) {
    selectedCountry = country;
    notifyListeners();
  }

  void processOTPLogin() async {
    //
    accountPhoneNumber = "+${selectedCountry.phoneCode}${phoneTEC.text}";
    // Validate returns true if the form is valid, otherwise false.
    if (formKey.currentState.validate()) {
      processCustomOTPVerification();
    }
  }

  processCustomOTPVerification() async {
    setBusyForObject(otpLogin, true);
    try {
      await _authRequest.sendOTP(accountPhoneNumber);
      setBusyForObject(otpLogin, false);
      showVerificationEntry();
    } catch (error) {
      setBusyForObject(otpLogin, false);
      viewContext.showToast(msg: "$error", bgColor: Colors.red);
    }
  }

  //
  void showVerificationEntry() async {
    //
    setBusy(false);
    //
    await viewContext.push(
      (context) => AccountVerificationEntry(
        vm: this,
        phone: accountPhoneNumber,
        onSubmit: (smsCode) {
          //

          verifyCustomOTP(smsCode);

          viewContext.pop();
        },
        onResendCode: AppStrings.isCustomOtp
            ? () async {
                try {
                  final response = await _authRequest.sendOTP(
                    accountPhoneNumber,
                  );
                  toastSuccessful(response.message);
                } catch (error) {
                  viewContext.showToast(msg: "$error", bgColor: Colors.red);
                }
              }
            : null,
      ),
    );
  }

  void verifyCustomOTP(String smsCode) async {
    //
    setBusy(true);
    // Sign the user in (or link) with the credential
    try {
      final apiResponse = await _authRequest.verifyOTP(
        accountPhoneNumber,
        smsCode,
        isLogin: false,
      );

      //
      await handleDeviceLogin(apiResponse);
    } catch (error) {
      viewContext.showToast(msg: "$error", bgColor: Colors.red);
    }
    //
    setBusy(false);
  }

  //QRCode login
  void initateQrcodeLogin() async {
    //
    final loginCode = await openScanner(viewContext);
    if (loginCode == null) {
      toastError("Operation failed/cancelled".tr());
    } else {
      setBusy(true);

      try {
        final apiResponse = await _authRequest.qrLoginRequest(
          code: loginCode,
        );
        //
        handleDeviceLogin(apiResponse);
      } catch (error) {
        print("QR Code login error ==> $error");
      }

      setBusy(false);
    }
  }

  ///
  ///
  ///
  handleDeviceLogin(ApiResponse apiResponse) async {
    try {
      if (apiResponse.hasError()) {
        //there was an error
        CoolAlert.show(
          context: viewContext,
          type: CoolAlertType.error,
          title: "Login Failed".tr(),
          text: apiResponse.message,
        );
      } else {
        //everything works well
        //firebase auth
        final fbToken = apiResponse.body["fb_token"];
        await FirebaseAuth.instance.signInWithCustomToken(fbToken);
        await AuthServices.saveUser(apiResponse.body["user"]);
        await AuthServices.saveVendor(apiResponse.body["vendor"]);
        await AuthServices.setAuthBearerToken(apiResponse.body["token"]);
        await AuthServices.isAuthenticated();
        viewContext.navigator.pushNamedAndRemoveUntil(
          AppRoutes.homeRoute,
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (error) {
      CoolAlert.show(
        context: viewContext,
        type: CoolAlertType.error,
        title: "Login Failed".tr(),
        text: "${error.message}",
      );
    } catch (error) {
      CoolAlert.show(
        context: viewContext,
        type: CoolAlertType.error,
        title: "Login Failed".tr(),
        text: "$error",
      );
    }
  }

  void openForgotPassword() {
    viewContext.navigator.pushNamed(
      AppRoutes.forgotPasswordRoute,
    );
  }

  void openRegistrationlink() async {
    final url = Api.register;
    openExternalWebpageLink(url);
  }
}
