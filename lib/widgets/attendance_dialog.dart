import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:get/get_core/get_core.dart';
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
      borderRadius: BorderRadius.circular(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Weather section and time counter
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  "Attendance",
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
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
                      const Text(":", style: TextStyle(fontSize: 50)),
                      _timeDisplay(
                        elapsedTime.inMinutes
                            .remainder(60)
                            .toString()
                            .padLeft(2, '0'),
                      ),
                      // _timeDisplay(
                      //   elapsedTime.inSeconds
                      //       .remainder(60)
                      //       .toString()
                      //       .padLeft(2, '0'),
                      // ),
                    ],
                  );
                }),

                Gap(20),
                Row(children: [Text("Recent activity")]),
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
                        Obx(
                          () => Text(
                            (controller
                                    .attendanceController
                                    .workHoursTime
                                    .value ??
                                "00:00"),
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Text("Hours worked", style: TextStyle(fontSize: 12)),
                      ],
                    ),

                    Column(
                      children: [
                        SvgPicture.asset(bikeSVG, width: 30, height: 30),
                        Gap(5),
                        Obx(
                          () => Text(
                            "${controller.attendanceController.totalDistanceKm.value} KM",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Text("Traveled", style: TextStyle(fontSize: 12)),
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

  Widget _timeDisplay(String value) {
    return Container(
      width: 60,
      height: 60,

      alignment: Alignment.center,
      child: Text(value, style: const TextStyle(fontSize: 50)),
    );
  }
}
