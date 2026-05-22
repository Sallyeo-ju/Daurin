import 'package:flutter/material.dart';
import 'LoginPage.dart'; // Gunakan ini saja daripada package:Daurin_App/...

void main() {
  runApp(const Main());
}

class Main extends StatelessWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daurin App'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Selamat Datang di Daurin!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
           ElevatedButton(
            onPressed: () {
              Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },  
            child: const Text('Mulai Daur Ulang'),
            ),
          ],
        ),
      ),
    );
  }
}
