import 'package:flutter/material.dart';
import 'package:fuodz/constants/app_colors.dart';
import 'package:fuodz/constants/app_text_styles.dart';
import 'package:fuodz/widgets/busy_indicator.dart';

class CustomTextButton extends StatelessWidget {
  final Function onPressed;
  final String title;
  final bool loading;
  const CustomTextButton({
    this.onPressed,
    this.title,
    this.loading = false,
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: this.onPressed,
      child: loading
          ? Center(
              child: BusyIndicator(),
            )
          : Text(
        this.title,
        style: AppTextStyle.h4TitleTextStyle(
          color: AppColor.primaryColor,
        ),
      ),
    );
  }
}
