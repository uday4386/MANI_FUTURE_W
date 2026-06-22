import 'package:flutter/material.dart';
import 'main_navigation.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../data/locations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import '../widgets/translated_text.dart';
import '../widgets/app_logo.dart';

class LocationScreen extends StatefulWidget {
  final String selectedLanguage;
  const LocationScreen({super.key, required this.selectedLanguage});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String? selectedState;
  String? selectedDistrict;
  String? selectedCity;

  List<String> states = [];
  List<String> districts = [];
  List<String> cities = [];

  bool _isLoadingLocation = false;

  // 🔤 Language-specific text
  late Map<String, dynamic> text;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    // Initialize states from data
    states = locationData.keys.toList();
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getString('user_state');
    final savedDistrict = prefs.getString('user_district');
    final savedCity = prefs.getString('user_city');

    if (savedState != null && locationData.containsKey(savedState)) {
      if (mounted) {
        setState(() {
          selectedState = savedState;
          districts = locationData[savedState]!.keys.toList();

          if (savedDistrict != null && districts.contains(savedDistrict)) {
            selectedDistrict = savedDistrict;
            cities = locationData[savedState]![savedDistrict] ?? [];

            if (savedCity != null && cities.contains(savedCity)) {
              selectedCity = savedCity;
            }
          }
        });
      }
    } else {
      _autoDetectLocation();
    }
  }

  void _loadLanguage() {
    if (widget.selectedLanguage == "తెలుగు" ||
        widget.selectedLanguage == "Telugu") {
      text = {
        "title": "మీ స్థానాన్ని ఎంచుకోండి",
        "subtitle": "మీ ప్రాంతం వార్తలను అందించడానికి",
        "state": "రాష్ట్రం",
        "district": "జిల్లా",
        "city": "నగరం / పట్టణం",
        "selectState": "రాష్ట్రాన్ని ఎంచుకోండి",
        "selectDistrict": "జిల్లాను ఎంచుకోండి",
        "selectCity": "నగరాన్ని ఎంచుకోండి",
        "continue": "కొనసాగించండి",
      };
    } else {
      text = {
        "title": "Select Your Location",
        "subtitle": "To deliver news from your area",
        "state": "State",
        "district": "District",
        "city": "City / Town",
        "selectState": "Select a state",
        "selectDistrict": "Select a district",
        "selectCity": "Select a city",
        "continue": "Continue",
      };
    }
  }

  Future<void> _autoDetectLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      if (!mounted) return;
      _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("Auto-detect location error: $e");
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      // Using Nominatim OpenStreetMap API (Free, no key required)
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1",
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'SamanyuduNewsApp/1.0'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data["address"];

        if (address != null) {
          String? detectedState = address["state"];
          String? detectedDistrict = address["county"] ?? address["district"];
          String? detectedCity =
              address["city"] ??
              address["town"] ??
              address["village"] ??
              address["suburb"];

          // Clean up district name (remove 'District' suffix if present)
          if (detectedDistrict != null) {
            detectedDistrict = detectedDistrict
                .replaceAll(" District", "")
                .trim();
          }

          setState(() {
            // Update State
            if (detectedState != null &&
                locationData.containsKey(detectedState)) {
              selectedState = detectedState;

              // Populate districts for selected state
              districts = locationData[selectedState]!.keys.toList();

              // Update District
              if (detectedDistrict != null &&
                  districts.contains(detectedDistrict)) {
                selectedDistrict = detectedDistrict;

                // Populate cities for selected district
                cities = locationData[selectedState]![selectedDistrict] ?? [];

                // Update City
                // Check if detected city matches any in the list (fuzzy match or exact)
                // For simplicity, we check exact match or if detectedCity contains list item
                if (detectedCity != null) {
                  // Try to find a match in our curated list
                  try {
                    String? match = cities.firstWhere(
                      (c) =>
                          detectedCity!.toLowerCase().contains(
                            c.toLowerCase(),
                          ) ||
                          c.toLowerCase().contains(detectedCity.toLowerCase()),
                      orElse: () => "",
                    );
                    if (match != null && match.isNotEmpty) selectedCity = match;
                  } catch (e) {
                    // no city match found, ignore city auto-select
                  }
                }
              } else {
                selectedDistrict = null;
                cities = [];
                selectedCity = null;
              }
            }

            _isLoadingLocation = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (widget.selectedLanguage == "తెలుగు" ||
                        widget.selectedLanguage == "Telugu")
                    ? "స్థానం గుర్తించబడింది!"
                    : "Location detected!",
              ),
            ),
          );
        } else {
          if (mounted) setState(() => _isLoadingLocation = false);
        }
      } else {
        if (mounted) setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      debugPrint("Reverse geocode error: $e");
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void goToMain() async {
    if (selectedState != null &&
        selectedDistrict != null &&
        selectedCity != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_state', selectedState!);
      await prefs.setString('user_district', selectedDistrict!);
      await prefs.setString('user_city', selectedCity!);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MainNavigation(selectedLanguage: widget.selectedLanguage),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (widget.selectedLanguage == "తెలుగు" ||
                    widget.selectedLanguage == "Telugu")
                ? "దయచేసి అన్ని వివరాలు ఎంచుకోండి"
                : "Please select all fields",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final bgColor = isDark ? const Color(0xFF0B2A45) : Colors.white;
    final fieldColor = isDark ? const Color(0xFF173B60) : Colors.grey[200];
    final hintColor = isDark ? Colors.white54 : Colors.black54;
    final dropdownTextColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const AppLogo(fontSize: 32),
                const SizedBox(height: 30),
                Icon(Icons.location_on, color: const Color(0xFFFFC107), size: 40),
                const SizedBox(height: 12),
                if (_isLoadingLocation)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(
                      color: const Color(0xFFFFC107),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                Text(
                  text["title"],
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isLoadingLocation ? null : _autoDetectLocation,
                  icon: Icon(
                    Icons.my_location,
                    color: const Color(0xFFFFC107),
                    size: 18,
                  ),
                  label: Text(
                    (widget.selectedLanguage == "తెలుగు" ||
                            widget.selectedLanguage == "Telugu")
                        ? "ప్రస్తుత స్థానాన్ని ఉపయోగించండి"
                        : "Use Current Location",
                    style: const TextStyle(color: const Color(0xFFFFC107)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text["subtitle"],
                  style: TextStyle(color: subTextColor, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // 🔽 State Dropdown
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text["state"],
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  dropdownColor: fieldColor,
                  style: TextStyle(color: dropdownTextColor),
                  value: selectedState,
                  hint: Text(
                    text["selectState"],
                    style: TextStyle(color: hintColor),
                  ),
                  items: states.map((s) {
                    // Get localized name
                    String label = s;
                    if (widget.selectedLanguage == "తెలుగు" ||
                        widget.selectedLanguage == "Telugu") {
                      label = stateTranslations[s] ?? s;
                    }
                    return DropdownMenuItem(
                      value: s,
                      child: Text(
                        label,
                        style: TextStyle(color: dropdownTextColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != selectedState) {
                      setState(() {
                        selectedState = val;
                        // Load districts
                        districts = locationData[val]!.keys.toList();
                        selectedDistrict = null;
                        cities = [];
                        selectedCity = null;
                      });
                    }
                  },
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 20),

                // 🔽 District Dropdown
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text["district"],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  dropdownColor: fieldColor,
                  style: TextStyle(color: dropdownTextColor),
                  value: selectedDistrict,
                  hint: Text(
                    text["selectDistrict"],
                    style: TextStyle(color: hintColor),
                  ),
                  items: districts.map((s) {
                    String label = s;
                    if (widget.selectedLanguage == "తెలుగు" ||
                        widget.selectedLanguage == "Telugu") {
                      label = districtTranslations[s] ?? s;
                    }
                    return DropdownMenuItem(
                      value: s,
                      child: Text(
                        label,
                        style: TextStyle(color: dropdownTextColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != selectedDistrict) {
                      setState(() {
                        selectedDistrict = val;
                        // Load cities for selected district
                        cities = locationData[selectedState]![val] ?? [];
                        selectedCity = null;
                      });
                    }
                  },
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 20),

                // 🔽 City Dropdown
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text["city"],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  dropdownColor: fieldColor,
                  style: TextStyle(color: dropdownTextColor),
                  value: selectedCity,
                  hint: Text(
                    text["selectCity"],
                    style: TextStyle(color: hintColor),
                  ),
                  items: cities.map((s) {
                    String label = s;
                    if ((widget.selectedLanguage == "తెలుగు" ||
                            widget.selectedLanguage == "Telugu") &&
                        selectedState != null &&
                        selectedDistrict != null) {
                      // Find index of s in English list
                      int idx = locationData[selectedState]![selectedDistrict]!
                          .indexOf(s);
                      // Check if translation map has corresponding entry
                      if (locationDataTelugu.containsKey(selectedState) &&
                          locationDataTelugu[selectedState]!.containsKey(
                            selectedDistrict,
                          )) {
                        List<String>? teluguCities =
                            locationDataTelugu[selectedState]![selectedDistrict];
                        if (teluguCities != null &&
                            idx >= 0 &&
                            idx < teluguCities.length) {
                          label = teluguCities[idx];
                        }
                      }
                    }
                    return DropdownMenuItem(
                      value: s,
                      child: Text(
                        label,
                        style: TextStyle(color: dropdownTextColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedCity = val),
                  decoration: _inputDecoration(),
                ),
                
                const SizedBox(height: 40),

                // Continue Button
                ElevatedButton(
                  onPressed: goToMain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 70,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    text["continue"],
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? const Color(0xFF173B60) : Colors.grey[200];
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : Colors.black54;

    return InputDecoration(
      filled: true,
      fillColor: fieldColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: const Color(0xFFFFC107), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
