import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:get/get_core/get_core.dart';
import 'package:get_x_storage/get_x_storage.dart';
import 'package:grownext/Data/Controllers/home_controller.dart';
import 'package:grownext/Data/consts/app_string.dart';
import 'package:grownext/Data/extenstions/greeting_by_time.dart';
import 'package:grownext/Data/models/user_model.dart';
import 'package:grownext/Data/theme/colors.dart';
import 'package:grownext/service_location.dart';
import 'package:logger/logger.dart';

class AttendanceDialog extends StatelessWidget {
  const AttendanceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Material(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Weather section and time counter
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(
                  "${sl<UserModel>().name}".greet(),
                  style: TextStyle(fontSize: 20),
                ),
                const Gap(20),

                Obx(
                  () => ElevatedButton(
                    onPressed: () {
                      // controller.attendanceController.getAreaName();
                      // return;
                      // Logger().d('Punch In button pressed');
                      controller.attendanceController.isCheckedIn.value
                          ? controller.attendanceController.checkOut()
                          : controller.attendanceController.checkIn();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          controller.attendanceController.isCheckedIn.value
                          ? Colors.red
                          : primaryColor,
                      minimumSize: Size.fromRadius(70),
                      shape: CircleBorder(),
                    ),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          fingerprintSVG,
                          width: 70,
                          height: 70,
                          colorFilter: ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        Text(
                          controller.attendanceController.currentStatus.value,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(mapPinSVG, width: 20, height: 20),

                    Text("Your current location"),
                  ],
                ),
                Obx(
                  () => Text(
                    "${controller.attendanceController.localAreaName}",
                    style: TextStyle(color: Colors.black),
                  ),
                ),

                const Gap(20),

                // Time counter
                Obx(() {
                  final elapsedTime =
                      controller.attendanceController.elapsedTime.value;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _timeDisplay(
                        elapsedTime.inHours.toString().padLeft(2, '0'),
                      ),
                      _timeDisplay(
                        elapsedTime.inMinutes
                            .remainder(60)
                            .toString()
                            .padLeft(2, '0'),
                      ),
                      _timeDisplay(
                        elapsedTime.inSeconds
                            .remainder(60)
                            .toString()
                            .padLeft(2, '0'),
                      ),
                      const Text("HRS", style: TextStyle(fontSize: 15)),
                    ],
                  );
                }),

                Gap(20),
                Row(children: [Text("Todays history")]),
                Gap(10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        SvgPicture.asset(
                          clockArrowUpSVG,
                          width: 30,
                          height: 30,
                        ),
                        Gap(5),
                        Obx(
                          () => Text(
                            controller.attendanceController.checkInTime.value ??
                                "00:00",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),

                        Text("Clocked-in", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        SvgPicture.asset(
                          clockArrowDownSVG,
                          width: 30,
                          height: 30,
                        ),
                        Gap(5),
                        Obx(
                          () => Text(
                            controller
                                    .attendanceController
                                    .checkOutTime
                                    .value ??
                                "00:00",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),

                        Text("Clocked-out", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        SvgPicture.asset(clockFadingSVG, width: 30, height: 30),
                        Gap(5),
                        Text(
                          controller.attendanceController.workHoursTime.value ??
                              "00:00",
                          style: TextStyle(fontSize: 12),
                        ),
                        Text("Working hours", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherIcon(String type) {
    if (type == 'sun') {
      return Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(subSVG),

              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFAA33),
                  shape: BoxShape.circle,
                ),
              ),
              // Sun rays
            ],
          ),
        ],
      );
    } else {
      return Column(children: [SvgPicture.asset(cloudSVG)]);
    }
  }

  Widget _timeDisplay(String value) {
    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7E1),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(value, style: const TextStyle(fontSize: 20)),
    );
  }
}
