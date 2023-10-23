import 'dart:typed_data';

import 'package:fine_merchant_mobile/Accessories/dialog.dart';
import 'package:fine_merchant_mobile/Constant/enum.dart';
import 'package:fine_merchant_mobile/Constant/view_status.dart';
import 'package:fine_merchant_mobile/Utils/constrant.dart';
import 'package:fine_merchant_mobile/ViewModel/account_viewModel.dart';
import 'package:fine_merchant_mobile/ViewModel/base_model.dart';
import 'package:fine_merchant_mobile/ViewModel/station_viewModel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Model/DAO/index.dart';
import '../Model/DTO/index.dart';

class HomeViewModel extends BaseModel {
  // constant

  // local properties
  static String selectedDestinationId = '70248C0D-C39F-468F-9A92-4A5A7F1FF6BB';
  List<DeliveryPackageDTO> pendingPackageList = [];
  List<DeliveryPackageDTO> takenPackageList = [];
  List<ShipperOrderBoxDTO> orderBoxList = [];
  List<OrderDTO> orderDetailList = [];
  List<OrderDTO> filteredOrderList = [];
  List<StationDTO> stationList = [];
  List<StoreDTO> storeList = [];
  List<TimeSlotDTO> timeSlotList = [];
  // Data Object Model
  OrderDAO? _orderDAO;
  StationDAO? _stationDAO;
  StoreDAO? _storeDAO;
  TimeSlotDAO? _timeSlotDAO;
  SplitProductDAO? _splitProductDAO;
  dynamic error;
  OrderDTO? orderDTO;
  Uint8List? imageBytes;
  // Widget
  ScrollController? scrollController;
  bool isDelivering = false;
  PackageViewDTO? currentDeliveryPackage;
  String selectedStationId = '';
  String selectedTimeSlotId = 'e8d529d4-6a51-4fdb-b9db-e29f54c0486e';
  String selectedStoreId = '';
  final ValueNotifier<int> notifierPending = ValueNotifier(0);
  final ValueNotifier<int> notifierTaken = ValueNotifier(0);

  HomeViewModel() {
    _orderDAO = OrderDAO();
    _stationDAO = StationDAO();
    _storeDAO = StoreDAO();
    _timeSlotDAO = TimeSlotDAO();
    _splitProductDAO = SplitProductDAO();
    scrollController = ScrollController();
  }

  Future<void> onChangeStore(String value) async {
    selectedStoreId = value;
    // getOrders();
    await getDeliveryPackageListForDriver();
    notifyListeners();
  }

  Future<void> onChangeStation(String value) async {
    selectedStationId = value;
    // await getDeliveredOrdersForDriver();
    await getDeliveryPackageListForDriver();
    notifyListeners();
  }

  Future<void> onChangeTimeSlot(String value) async {
    selectedTimeSlotId = value;
    // await getDeliveredOrdersForDriver();
    await getDeliveryPackageListForDriver();
    notifyListeners();
  }

  Future<void> getTimeSlotList() async {
    try {
      final data = await _timeSlotDAO?.getTimeSlots(
          destinationId: selectedDestinationId);
      if (data != null) {
        timeSlotList = data
            .where((slot) => (int.parse(slot.arriveTime!.substring(0, 2)) -
                    DateTime.now().hour >=
                1))
            .toList();
        if (timeSlotList.isEmpty) {
          var lastTimeSlot = data.last;
          timeSlotList.add(lastTimeSlot);
          selectedTimeSlotId = lastTimeSlot.id!;
        } else if (selectedTimeSlotId == '' ||
            timeSlotList.firstWhereOrNull((e) => e.id == selectedTimeSlotId) ==
                null) {
          selectedTimeSlotId = timeSlotList.first.id!;
        }
      }

      notifyListeners();
    } catch (e) {
      bool result = await showErrorDialog();
      if (result) {
        await getTimeSlotList();
      }
    }
  }

  Future<void> getStationList() async {
    try {
      var currentUser = Get.find<AccountViewModel>().currentUser;

      final data = await _stationDAO?.getStationsByDestination(
          destinationId: selectedDestinationId);
      if (data != null) {
        stationList = data;
        String? selectedStationCodeByName =
            currentUser?.username!.replaceFirst("shipper", '');
        String? findNumber =
            selectedStationCodeByName?.replaceAll(RegExp(r'[^0-9]'), '');
        selectedStationCodeByName =
            selectedStationCodeByName?.replaceFirst(RegExp(r'\d'), '');

        selectedStationCodeByName =
            ("${selectedStationCodeByName!}L${findNumber!}").toUpperCase();

        StationDTO? foundStation = stationList.firstWhereOrNull(
            (station) => station.code == selectedStationCodeByName);
        if (foundStation != null) {
          selectedStationId = foundStation.id!;
        } else {
          selectedStationId = "";
        }

        // selectedStationId = data.first.id!;
      }

      notifyListeners();
    } catch (e) {
      bool result = await showErrorDialog();
      if (result) {
        await getStationList();
      }
    } finally {}
  }

  Future<void> getStoreList() async {
    try {
      final data = await _storeDAO?.getStores();
      if (data != null) {
        storeList = data;
        if (selectedStoreId == '') {
          selectedStoreId = data.first.id!;
        }
      }

      notifyListeners();
    } catch (e) {
      bool result = await showErrorDialog();
      if (result) {
        await getStoreList();
      }
    } finally {}
  }

  Future<void> getDeliveryPackageListForDriver() async {
    try {
      // setState(ViewStatus.Loading);

      var currentUser = Get.find<AccountViewModel>().currentUser;
      if (currentUser != null) {
        final data = await _splitProductDAO?.getDeliveryPackageListForDriver(
          timeSlotId: selectedTimeSlotId,
        );
        if (data != null) {
          List<DeliveryPackageDTO> newTakenPackages = [];
          List<DeliveryPackageDTO> newPendingPackages = [];
          for (DeliveryPackageDTO package in data) {
            if (package.isTaken == true) {
              newTakenPackages.add(package);
            } else {
              newPendingPackages.add(package);
            }
          }
          takenPackageList = newTakenPackages;
          pendingPackageList = newPendingPackages;
          notifierPending.value = newPendingPackages.length;
          notifierTaken.value = newTakenPackages.length;
        }
      }
      // setState(ViewStatus.Completed);
      notifyListeners();
    } catch (e) {
      bool result = await showErrorDialog();
      if (result) {
        await getDeliveryPackageListForDriver();
      } else {
        // setState(ViewStatus.Error);
      }
    } finally {}
  }

  Future<void> getShipperOrderBoxes() async {
    try {
      setState(ViewStatus.Loading);
      imageBytes = null;
      var currentUser = Get.find<AccountViewModel>().currentUser;
      if (currentUser != null) {
        final data = await _orderDAO?.getShipperOrderBox(
          stationId: selectedStationId,
          timeSlotId: selectedTimeSlotId,
        );
        if (data != null) {
          orderBoxList = data;
        }
      }
      setState(ViewStatus.Completed);
      notifyListeners();
    } catch (e) {
      bool result = await showErrorDialog();
      if (result) {
        await getShipperOrderBoxes();
      } else {
        setState(ViewStatus.Error);
      }
    } finally {}
  }

  Future<void> confirmTakenPackage({required String storeId}) async {
    try {
      int option = await showOptionDialog("Đã lấy món ở cửa hàng này?");

      if (option == 1) {
        showLoadingDialog();

        final statusCode = await _splitProductDAO?.confirmTakenProduct(
            storeId: storeId, timeSlotId: selectedTimeSlotId);
        if (statusCode == 200) {
          notifyListeners();
          await showStatusDialog(
              "assets/images/icon-success.png", "Lấy thành công", "");
          Get.back();
        } else {
          await showStatusDialog(
            "assets/images/error.png",
            "Thất bại",
            "",
          );
        }
      }
    } catch (e) {
      await showStatusDialog(
        "assets/images/error.png",
        "Thất bại",
        "Có lỗi xảy ra, vui lòng thử lại sau 😓",
      );
    } finally {
      await getDeliveryPackageListForDriver();
    }
  }

  Future<void> confirmAllBoxStored() async {
    int option = await showOptionDialog(
        "Xác nhận đã bỏ đủ hàng vào các tủ?, Mọi trường hợp thiếu món sau đó sẽ do bạn chịu trách nhiệm.");
    if (option == 1) {
      try {
        showLoadingDialog();

        final statusCode = await _splitProductDAO?.confirmAllInBoxes(
            timeSlotId: selectedTimeSlotId);
        if (statusCode == 200) {
          notifyListeners();
          await showStatusDialog(
              "assets/images/icon-success.png", "Giao thành công", "");
          Get.back();
        } else {
          await showStatusDialog(
            "assets/images/error.png",
            "Thất bại",
            "",
          );
        }
      } catch (e) {
        await showStatusDialog(
          "assets/images/error.png",
          "Thất bại",
          "Có lỗi xảy ra, vui lòng thử lại sau 😓",
        );
      } finally {
        await getDeliveryPackageListForDriver();
      }
    }
  }

  Future<void> getBoxQrCode() async {
    try {
      setState(ViewStatus.Loading);

      if (orderBoxList.isNotEmpty) {
        var requestData = [];
        for (ShipperOrderBoxDTO orderBox in orderBoxList) {
          List<OrderDetail>? orderDetails = orderBox.orderDetails;
          if (orderDetails!.isNotEmpty) {
            requestData.add(StationQrCodeRequestModel(
                    boxId: orderBox.boxId?.toUpperCase(),
                    orderId: orderDetails.first.orderId?.toUpperCase())
                .toJson());
          }
        }
        final qrCode =
            await _stationDAO!.getQrCodeForShipper(requestData: requestData);
        if (qrCode != null) {
          imageBytes = qrCode;
        }
      }

      await Future.delayed(const Duration(milliseconds: 200));
      notifyListeners();
      setState(ViewStatus.Completed);
    } catch (e) {
      bool result = await showErrorDialog();
      if (result) {
        await getBoxQrCode();
      } else {
        setState(ViewStatus.Error);
      }
    } finally {}
  }
}
