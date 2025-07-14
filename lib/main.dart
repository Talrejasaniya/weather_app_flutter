import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';


final logger = Logger();

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  logger.i('API Key Loaded: ${dotenv.env['API_KEY']}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WeatherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  WeatherScreenState createState() => WeatherScreenState();
}

class WeatherScreenState extends State<WeatherScreen> {
  String? temperature;
  String? description;
  String? errorMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getWeather();
  }

  Future<void> getWeather() async {
    logger.i('Requesting location permission...');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        setState(() {
          errorMessage = "Location permission not granted.";
          isLoading = false;
        });
        logger.w('Permission not granted.');
        return;
      }
    }

    try {
      logger.i('Fetching current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      double lat = position.latitude;
      double lon = position.longitude;
      logger.i('Location: $lat, $lon');

      final String openWeatherApiKey = dotenv.env['API_KEY'] ?? '';

      final String url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$openWeatherApiKey&units=metric';

      logger.i('Requesting weather data...');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          temperature = data['main']['temp'].toString();
          description = data['weather'][0]['description'];
          isLoading = false;
        });

        logger.i('Weather data fetched.');
      } else {
        setState(() {
          errorMessage = 'Failed to load weather: ${response.statusCode}';
          isLoading = false;
        });
        logger.e('HTTP error ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred while fetching weather data.';
        isLoading = false;
      });
      logger.e('Exception: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather App')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const CircularProgressIndicator()
              : errorMessage != null
                  ? Text(
                      errorMessage!,
                      style: const TextStyle(fontSize: 18, color: Colors.red),
                      textAlign: TextAlign.center,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.thermostat,
                            size: 50, color: Colors.orange),
                        const SizedBox(height: 20),
                        Text(
                          "🌡 Temperature: ${temperature ?? '--'} °C",
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "🌥 Description: ${description ?? 'N/A'}",
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
