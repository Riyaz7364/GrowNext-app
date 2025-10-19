import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:grownext/Data/consts/app_string.dart';
import 'package:grownext/Data/theme/colors.dart';
import 'package:grownext/widgets/attendance_dialog.dart';
import 'package:nb_utils/nb_utils.dart';

class BottomWebViewControls extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onTasks;
  final VoidCallback checkInOut;
  final VoidCallback onCalendar;
  final VoidCallback onMenu;

  const BottomWebViewControls({
    super.key,
    required this.onHome,
    required this.onTasks,
    required this.checkInOut,
    required this.onCalendar,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Bottom bar background
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(0),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: Offset(-10, 0),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    iconNavButton(
                      lable: "Home",
                      svg: homeSVG,
                      onPressed: onHome,
                    ),
                    iconNavButton(
                      lable: "Tasks",
                      svg: taskSVG,
                      onPressed: onTasks,
                    ),

                    Gap(0),
                  ],
                ),
              ),
            ),
            Container(height: 50, width: 40, color: white),
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: Offset(10, 0),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Gap(0),
                    iconNavButton(
                      lable: "Calendar",
                      svg: calendarDaysSVG,
                      onPressed: onCalendar,
                    ),
                    iconNavButton(
                      lable: "Menu",
                      svg: menuSVG,
                      onPressed: onMenu,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(height: 60, width: 50, color: Colors.white),
        Positioned(
          top: -20,
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                isScrollControlled: true,
                context: context,

                builder: (context) => AttendanceDialog(),
              );
            },
            child: Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SvgPicture.asset(
                alarmClockSVG,

                colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ).paddingAll(15),
            ),
          ),
        ),
      ],
    );
  }

  Widget iconNavButton({
    required String svg,
    required String lable,
    VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(svg),
        Text(lable, style: TextStyle(fontSize: 12)),
      ],
    ).onTap(onPressed);
  }
}
