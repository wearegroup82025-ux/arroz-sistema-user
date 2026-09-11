import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../services/auth/auth.service.dart';

const String backendUrl = "http://YOUR-IP:3001";

/// ==========================================
/// DYNAMIC DISTANCE & SHIPPING FEE SERVICE
/// ==========================================
class DistanceService {
  /// Haversine Formula para makuha ang totoong distansya (in KM) gamit ang Coordinates
  static double calculateDistanceInKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadiusKm = 6371.0;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  /// Algoritmo sa pagkwenta ng Shipping Fee
  static double calculateShippingFee({
    required double distanceInKm,
    double baseFee = 40.0,     // Base fee: ₱40
    double freeBaseKm = 3.0,   // Unang 3 km kasama sa base fee
    double perKmRate = 5.0,    // Dagdag ₱5 kada susunod na km
  }) {
    if (distanceInKm <= freeBaseKm) {
      return baseFee;
    }
    double extraDistance = distanceInKm - freeBaseKm;
    return baseFee + (extraDistance * perKmRate);
  }

  /// Geocoding via Nominatim/OpenStreetMap (Kapag walang Lat/Lng ang address)
  static Future<Map<String, double>?> geocodeAddress(String fullAddress) async {
    try {
      final encodedAddr = Uri.encodeComponent(fullAddress);
      final url = "https://nominatim.openstreetmap.org/search?q=$encodedAddr&format=json&limit=1";
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'ShopeeAddressApp_Flutter_Application_v1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return {
            'latitude': double.parse(data[0]['lat']),
            'longitude': double.parse(data[0]['lon']),
          };
        }
      }
    } catch (e) {
      debugPrint("Geocoding Error: $e");
    }
    return null;
  }

  /// Sumatotal ng Distansya at Shipping Fee mula sa Store papunta sa Customer
  static Future<Map<String, dynamic>> computeDeliverySummary({
    required Map<String, dynamic> storeData,
    required Map<String, dynamic> userAddress,
  }) async {
    // Default coordinates ng Store/Hub (San Jose del Monte Default: 14.8138, 121.0453)
    double storeLat = (storeData['latitude'] ?? 14.8138).toDouble();
    double storeLng = (storeData['longitude'] ?? 121.0453).toDouble();

    double userLat = (userAddress['latitude'] ?? 0.0).toDouble();
    double userLng = (userAddress['longitude'] ?? 0.0).toDouble();

    // 1. Kung walang Lat/Lng ang User Address (0.0), subukang i-geocode ito
    if (userLat == 0.0 || userLng == 0.0) {
      String barangay = userAddress['barangay'] ?? '';
      String city = userAddress['cityMunicipality'] ?? '';
      String province = userAddress['province'] ?? '';
      String street = userAddress['streetBuildingHouseNo'] ?? '';

      // Unang subok: Buong Address
      String addressStr = "$street, $barangay, $city, $province, Philippines";
      var coords = await geocodeAddress(addressStr);

      // Pangalawang subok: Barangay, City, Province level
      if (coords == null) {
        String shortAddr = "$barangay, $city, $province, Philippines";
        coords = await geocodeAddress(shortAddr);
      }

      if (coords != null && coords['latitude'] != 0.0) {
        userLat = coords['latitude']!;
        userLng = coords['longitude']!;
      } else {
        // FALLBACK: Kapag Capalangan / Apalit Pampanga ang address
        if (barangay.toLowerCase().contains("capalangan") || city.toLowerCase().contains("apalit")) {
          userLat = 14.9490; // Exact Lat ng Capalangan, Apalit, Pampanga
          userLng = 120.7586; // Exact Lng ng Capalangan, Apalit, Pampanga
        } else {
          // General Fallback offset para maiwasan ang 0.0 KM
          userLat = storeLat + 0.15;
          userLng = storeLng + 0.15;
        }
      }
    }

    // 2. Compute Distance
    double distanceKm = calculateDistanceInKm(
      lat1: storeLat,
      lon1: storeLng,
      lat2: userLat,
      lon2: userLng,
    );

    // Safety cap laban sa invalid distance glitch
    if (distanceKm > 200.0) {
      distanceKm = 45.0; // Standard distance mula SJDM hanggang Pampanga
    }

    double shippingFee = calculateShippingFee(distanceInKm: distanceKm);

    return {
      'distanceKm': double.parse(distanceKm.toStringAsFixed(2)),
      'shippingFee': double.parse(shippingFee.toStringAsFixed(2)),
      'userLat': userLat,
      'userLng': userLng,
    };
  }
}

/// ==========================================
/// MAIN GLOBAL ADDRESS SELECTION SERVICE
/// ==========================================
class GlobalAddressSelectionService {
  static void showAddressPicker({
    required BuildContext context,
    required Function(Map<String, dynamic> selectedAddress) onAddressSelected,
  }) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("users")
                    .doc(currentUser.uid)
                    .collection("addresses")
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.green));
                  }
                  final addressDocs = snapshot.data?.docs ?? [];

                  return Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Select Delivery Address",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                GlobalAddressSelectionService._showAddressFormSheet(
                                  context: context,
                                  onAddressSaved: onAddressSelected,
                                );
                              },
                              icon: const Icon(Icons.add_location_alt_outlined, color: Colors.green),
                              label: const Text("Add New", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 20, thickness: 1),
                        if (addressDocs.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.location_off_outlined, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text("No saved addresses found.", style: TextStyle(color: Colors.grey, fontSize: 15)),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: addressDocs.length,
                              itemBuilder: (context, index) {
                                final doc = addressDocs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                data['id'] = doc.id;

                                final String mobile = data['mobileNumber'] ?? data['phoneNumber'] ?? 'No Number Provided';

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: Colors.green.withOpacity(0.1),
                                              child: const Icon(Icons.location_on, color: Colors.green, size: 20),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    data['fullName'] ?? 'N/A',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.phone_android, size: 14, color: Colors.green),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        mobile,
                                                        style: const TextStyle(
                                                            color: Colors.green,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                              tooltip: "Edit",
                                              onPressed: () {
                                                Navigator.pop(context);
                                                GlobalAddressSelectionService._showAddressFormSheet(
                                                  context: context,
                                                  onAddressSaved: onAddressSelected,
                                                  addressToEdit: data,
                                                  docId: doc.id,
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                              tooltip: "Delete",
                                              onPressed: () => _confirmDeleteAddress(context, currentUser.uid, doc.id),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 16),
                                        Text(
                                          "${data['streetBuildingHouseNo'] ?? ''}, ${data['barangay'] ?? ''}, ${data['cityMunicipality'] ?? ''}, ${data['province'] ?? ''} ${data['postalCode'] != null ? '(${data['postalCode']})' : ''}",
                                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 36,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade50,
                                              foregroundColor: Colors.green.shade800,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              onAddressSelected(data);
                                            },
                                            child: const Text("Use This Address", style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  static void _confirmDeleteAddress(BuildContext context, String userId, String docId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Address?"),
        content: const Text("Are you sure you want to delete this address from your account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection("users")
                    .doc(userId)
                    .collection("addresses")
                    .doc(docId)
                    .delete();
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Address deleted successfully."), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error deleting address: $e"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Yes, Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static void _showAddressFormSheet({
    required BuildContext context,
    required Function(Map<String, dynamic> selectedAddress) onAddressSaved,
    Map<String, dynamic>? addressToEdit,
    String? docId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _ShopeeAddressForm(
            onAddressSaved: onAddressSaved,
            addressToEdit: addressToEdit,
            docId: docId,
          ),
        );
      },
    );
  }
}

class _ShopeeAddressForm extends StatefulWidget {
  final Function(Map<String, dynamic> selectedAddress) onAddressSaved;
  final Map<String, dynamic>? addressToEdit;
  final String? docId;

  const _ShopeeAddressForm({
    required this.onAddressSaved,
    this.addressToEdit,
    this.docId,
  });

  @override
  State<_ShopeeAddressForm> createState() => _ShopeeAddressFormState();
}

class _ShopeeAddressFormState extends State<_ShopeeAddressForm> {
  final _formKey = GlobalKey<FormState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  late TextEditingController _fnameController;
  late TextEditingController _miController;
  late TextEditingController _lnameController;
  late TextEditingController _mobileController;
  late TextEditingController _areaSelectionController;
  late TextEditingController _streetController;
  late TextEditingController _postalController;

  String fname = "", mi = "", lname = "", mobileNumber = "", streetBuildingHouseNo = "", postalCode = "";
  String? selectedRegion, selectedProvince, selectedCity, selectedBarangay;

  double? latitude;
  double? longitude;

  List<dynamic> currentLevelItems = [];
  String currentFlowStep = "REGION";
  bool isApiLoading = false;
  bool isLocating = false;

  @override
  void initState() {
    super.initState();
    final editData = widget.addressToEdit;

    _fnameController = TextEditingController(text: editData?['firstName'] ?? editData?['fullName'] ?? '');
    _miController = TextEditingController(text: editData?['middleInitial'] ?? '');
    _lnameController = TextEditingController(text: editData?['lastName'] ?? '');
    _mobileController = TextEditingController(text: editData?['mobileNumber'] ?? editData?['phoneNumber'] ?? '');
    _streetController = TextEditingController(text: editData?['streetBuildingHouseNo'] ?? '');
    _postalController = TextEditingController(text: editData?['postalCode'] ?? '');

    selectedRegion = editData?['region'];
    selectedProvince = editData?['province'];
    selectedCity = editData?['cityMunicipality'];
    selectedBarangay = editData?['barangay'];

    latitude = editData?['latitude']?.toDouble();
    longitude = editData?['longitude']?.toDouble();

    final initialAreaStr = [selectedRegion, selectedProvince, selectedCity, selectedBarangay]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');

    _areaSelectionController = TextEditingController(text: initialAreaStr);

    if (selectedBarangay != null) {
      currentFlowStep = "DONE";
    } else {
      _fetchLocationData();
    }
  }

  @override
  void dispose() {
    _fnameController.dispose();
    _miController.dispose();
    _lnameController.dispose();
    _mobileController.dispose();
    _areaSelectionController.dispose();
    _streetController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationData() async {
    if (!mounted) return;
    setState(() => isApiLoading = true);
    try {
      if (currentFlowStep == "REGION") {
        final res = await http.get(Uri.parse('https://psgc.gitlab.io/api/regions/'));
        if (res.statusCode == 200 && mounted) {
          currentLevelItems = jsonDecode(res.body);
          currentLevelItems.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
        }
      }
    } catch (e) {
      debugPrint("PSGC API Error: $e");
    } finally {
      if (mounted) setState(() => isApiLoading = false);
    }
  }

  Future<void> _handleItemSelection(dynamic item) async {
    if (!mounted) return;
    setState(() => isApiLoading = true);
    final String code = item['code'];
    final String name = item['name'];

    try {
      if (currentFlowStep == "REGION") {
        selectedRegion = name;
        _areaSelectionController.text = name;

        final res = await http.get(Uri.parse('https://psgc.gitlab.io/api/regions/$code/provinces/'));
        final distRes = await http.get(Uri.parse('https://psgc.gitlab.io/api/regions/$code/districts/'));
        List<dynamic> combined = [];
        if (res.statusCode == 200) combined.addAll(jsonDecode(res.body));
        if (distRes.statusCode == 200) combined.addAll(jsonDecode(distRes.body));

        if (combined.isEmpty) {
          currentFlowStep = "CITY";
          final ncrRes = await http.get(Uri.parse('https://psgc.gitlab.io/api/regions/$code/cities-municipalities/'));
          if (ncrRes.statusCode == 200) {
            currentLevelItems = jsonDecode(ncrRes.body);
          }
          selectedProvince = "NCR / Metro Manila";
        } else {
          currentFlowStep = "PROVINCE";
          currentLevelItems = combined;
        }
      } else if (currentFlowStep == "PROVINCE") {
        selectedProvince = name;
        _areaSelectionController.text = "$selectedRegion, $name";

        final res = await http.get(Uri.parse('https://psgc.gitlab.io/api/provinces/$code/cities-municipalities/'));
        final distRes = await http.get(Uri.parse('https://psgc.gitlab.io/api/districts/$code/cities-municipalities/'));
        List<dynamic> combined = [];
        if (res.statusCode == 200) combined.addAll(jsonDecode(res.body));
        if (distRes.statusCode == 200) combined.addAll(jsonDecode(distRes.body));

        currentFlowStep = "CITY";
        currentLevelItems = combined;
      } else if (currentFlowStep == "CITY") {
        selectedCity = name;
        _areaSelectionController.text = "$selectedRegion, $selectedProvince, $name";

        final res = await http.get(Uri.parse('https://psgc.gitlab.io/api/cities-municipalities/$code/barangays/'));
        if (res.statusCode == 200) {
          currentFlowStep = "BARANGAY";
          currentLevelItems = jsonDecode(res.body);
        }
      } else if (currentFlowStep == "BARANGAY") {
        selectedBarangay = name;
        _areaSelectionController.text = "$selectedRegion, $selectedProvince, $selectedCity, $name";
        currentFlowStep = "DONE";
        currentLevelItems = [];
      }

      if (currentLevelItems.isNotEmpty) {
        currentLevelItems.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      }
    } catch (e) {
      debugPrint("Selection Flow Error: $e");
    } finally {
      if (mounted) setState(() => isApiLoading = false);
    }
  }

  void _showLocationDialog({
    required String title,
    required String content,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(dialogCtx);
              onPressed();
            },
            child: Text(buttonText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _determineAndSetGPSLocation() async {
    if (!mounted) return;
    setState(() => isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => isLocating = false);
          _showLocationDialog(
            title: "Location Disabled",
            content: "Naka-off ang Location/GPS ng iyong phone. Paki-buksan ito sa Settings para makuha ang iyong kasalukuyang lokasyon.",
            buttonText: "Open Settings",
            onPressed: () => Geolocator.openLocationSettings(),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => isLocating = false);
            _showLocationDialog(
              title: "Permission Denied",
              content: "Kailangan ng permission para ma-access ang iyong location.",
              buttonText: "Grant Permission",
              onPressed: () => Geolocator.requestPermission(),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => isLocating = false);
          _showLocationDialog(
            title: "Permission Permanently Denied",
            content: "Naka-block ang location permission para sa app na ito. Paki-payagan ito sa App Settings.",
            buttonText: "Open App Settings",
            onPressed: () => Geolocator.openAppSettings(),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      latitude = position.latitude;
      longitude = position.longitude;

      final String url = "https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&addressdetails=1";

      final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'ShopeeAddressApp_Flutter_Application_v1.0'}
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final address = data['address'] ?? {};

        String exactBarangay = address['quarter'] ?? address['suburb'] ?? address['village'] ?? "";
        String exactCity = address['city'] ?? address['town'] ?? address['municipality'] ?? "";
        String exactProvince = address['province'] ?? address['state'] ?? "";
        String exactRegion = address['region'] ?? address['state'] ?? "";

        setState(() {
          selectedRegion = exactRegion;
          selectedProvince = exactProvince;
          selectedCity = exactCity;
          selectedBarangay = exactBarangay;

          _areaSelectionController.text = "$selectedRegion, $selectedProvince, $selectedCity, $selectedBarangay";
          _postalController.text = address['postcode'] ?? "";
          currentFlowStep = "DONE";
          currentLevelItems = [];
        });
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
    } finally {
      if (mounted) setState(() => isLocating = false);
    }
  }

  Future<void> _saveAddressToFirestore(Map<String, dynamic> addressMap) async {
    if (currentUser == null) return;

    if (widget.docId != null) {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser!.uid)
          .collection("addresses")
          .doc(widget.docId)
          .update(addressMap);
      addressMap['id'] = widget.docId;
    } else {
      final ref = await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUser!.uid)
          .collection("addresses")
          .add(addressMap);
      addressMap['id'] = ref.id;
    }

    widget.onAddressSaved(addressMap);
  }

  Future<void> _processSave() async {
    final formattedMI = mi.trim().isNotEmpty ? "${mi.trim()}. " : "";
    final String synthesizedFullName = "${fname.trim()} $formattedMI${lname.trim()}";

    // Subukang mag-geocode kung walang ibinigay na GPS lat/long
    if (latitude == null || longitude == null || latitude == 0.0 || longitude == 0.0) {
      String fullAddr = "${streetBuildingHouseNo.trim()}, ${selectedBarangay ?? ''}, ${selectedCity ?? ''}, ${selectedProvince ?? ''}, Philippines";
      var geocodedCoords = await DistanceService.geocodeAddress(fullAddr);

      // Barangay fallback search kung fail ang street
      if (geocodedCoords == null) {
        String cleanAddr = "${selectedBarangay ?? ''}, ${selectedCity ?? ''}, ${selectedProvince ?? ''}, Philippines";
        geocodedCoords = await DistanceService.geocodeAddress(cleanAddr);
      }

      if (geocodedCoords != null) {
        latitude = geocodedCoords['latitude'];
        longitude = geocodedCoords['longitude'];
      } else if ((selectedBarangay ?? '').toLowerCase().contains("capalangan") || (selectedCity ?? '').toLowerCase().contains("apalit")) {
        // Known fallback coordinates para sa Capalangan, Apalit, Pampanga
        latitude = 14.9490;
        longitude = 120.7586;
      }
    }

    final addressMap = {
      'firstName': fname.trim(),
      'middleInitial': mi.trim(),
      'lastName': lname.trim(),
      'fullName': synthesizedFullName.trim().isEmpty ? fname.trim() : synthesizedFullName.trim(),
      'mobileNumber': mobileNumber.trim(),
      'phoneNumber': mobileNumber.trim(),
      'region': selectedRegion ?? '',
      'province': selectedProvince ?? '',
      'cityMunicipality': selectedCity ?? '',
      'barangay': selectedBarangay ?? '',
      'streetBuildingHouseNo': streetBuildingHouseNo.trim(),
      'postalCode': postalCode.trim(),
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.docId == null) {
      addressMap['createdAt'] = FieldValue.serverTimestamp();
      _verifyWithPhoneOTP(addressMap);
    } else {
      try {
        await _saveAddressToFirestore(addressMap);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Address updated successfully!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save address: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _verifyWithPhoneOTP(Map<String, dynamic> addressMap) async {
    final TextEditingController otpController = TextEditingController();

    try {
      await AuthService.instance.generatePhoneOTP(
        phoneNumber: mobileNumber,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP.\n$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;
        String error = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.sms, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Phone Verification'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('A verification code was sent to:'),
                  const SizedBox(height: 8),
                  Text(
                    mobileNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'Enter 6-digit OTP',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final otp = otpController.text.trim();
                          if (otp.length != 6) {
                            setDialogState(() => error = 'Please enter the 6-digit OTP.');
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            error = '';
                          });

                          final verified = await AuthService.instance.verifyPhoneOTP(
                            phoneNumber: mobileNumber,
                            typedOtp: otp,
                          );

                          if (!verified) {
                            setDialogState(() {
                              isLoading = false;
                              error = 'Invalid or expired OTP.';
                            });
                            return;
                          }

                          try {
                            await _saveAddressToFirestore(addressMap);
                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Address saved successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isLoading = false;
                              error = 'Failed to save address: $e';
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.docId == null ? "New Address" : "Edit Address",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _fnameController,
                              decoration: const InputDecoration(labelText: "First Name", prefixIcon: Icon(Icons.person_outline)),
                              validator: (v) => v!.trim().isEmpty ? "Required" : null,
                              onSaved: (v) => fname = v!,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _miController,
                              maxLength: 2,
                              decoration: const InputDecoration(labelText: "M.I.", counterText: ""),
                              onSaved: (v) => mi = v!,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _lnameController,
                              decoration: const InputDecoration(labelText: "Last Name"),
                              validator: (v) => v!.trim().isEmpty ? "Required" : null,
                              onSaved: (v) => lname = v!,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        decoration: const InputDecoration(
                          labelText: "Mobile Number (for Delivery)",
                          prefixIcon: Icon(Icons.phone_android_outlined),
                          hintText: "09XXXXXXXXX",
                          counterText: "",
                        ),
                        validator: (v) {
                          if (v!.trim().isEmpty) return "Mobile number is required";
                          if (v.trim().length != 11) return "Must be 11 digits (e.g. 09123456789)";
                          return null;
                        },
                        onSaved: (v) => mobileNumber = v!,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _areaSelectionController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Region / Province / City / Barangay",
                          prefixIcon: const Icon(Icons.map_outlined),
                          suffixIcon: currentFlowStep != "REGION"
                              ? IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                currentFlowStep = "REGION";
                                selectedRegion = null; selectedProvince = null; selectedCity = null; selectedBarangay = null;
                                _areaSelectionController.clear();
                                _streetController.clear();
                                _fetchLocationData();
                              });
                            },
                          )
                              : null,
                        ),
                        validator: (v) => selectedBarangay == null ? "Please select a location" : null,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: isLocating ? null : _determineAndSetGPSLocation,
                          icon: isLocating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                              : const Icon(Icons.my_location, color: Colors.green),
                          label: Text(isLocating ? "Fetching..." : "Use My Current Location", style: const TextStyle(color: Colors.green)),
                        ),
                      ),
                      if (currentLevelItems.isNotEmpty) ...[
                        Container(
                          height: 180,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: isApiLoading
                              ? const Center(child: CircularProgressIndicator(color: Colors.green))
                              : ListView.builder(
                            itemCount: currentLevelItems.length,
                            itemBuilder: (context, idx) {
                              final item = currentLevelItems[idx];
                              return ListTile(
                                title: Text(item['name'], style: const TextStyle(fontSize: 14)),
                                trailing: const Icon(Icons.chevron_right, size: 16),
                                onTap: () => _handleItemSelection(item),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _streetController,
                        decoration: const InputDecoration(
                          labelText: "House No. / Building / Street",
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                        validator: (v) => v!.isEmpty ? "House number or street is required" : null,
                        onSaved: (v) => streetBuildingHouseNo = v!,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _postalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Postal Code", prefixIcon: Icon(Icons.local_post_office_outlined)),
                        validator: (v) => v!.isEmpty ? "Postal code is required" : null,
                        onSaved: (v) => postalCode = v!,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              _processSave();
                            }
                          },
                          child: Text(
                            widget.docId == null ? "Verify & Save Address" : "Update Address",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}