import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EnterPage extends StatefulWidget {
  const EnterPage({Key? key}) : super(key: key);

  @override
  _EnterPageState createState() => _EnterPageState();
}

class _EnterPageState extends State<EnterPage> {
  // Create a global key that uniquely identifies the Form widget
  // and allows validation of the form.
  //
  final _formKey = GlobalKey<FormState>();

  String? host;
  String? login;
  String? password;

  bool passwordOrLoginIsIncorrect = false;
  bool workInProgress = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enter ActiveMap login')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                enabled: !workInProgress,
                initialValue: kReleaseMode ? null : 'amr34.activemap.ru',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'this field is required';
                  }
                  final regex = RegExp(r'\.\w{2}');
                  if (!regex.hasMatch(value)) {
                    return 'please enter correct url format';
                  }
                  return null;
                },
                onSaved: (x) {
                  host = x;
                },
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'enter host of server',
                    helperStyle: TextStyle(fontSize: 16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                enabled: !workInProgress,
                initialValue: kReleaseMode ? null : 'depadmin',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'this field is required';
                  }
                  return null;
                },
                onSaved: (x) {
                  login = x;
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'enter login',
                  helperStyle: TextStyle(fontSize: 16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                enabled: !workInProgress,
                initialValue: kReleaseMode ? null : '123456789',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'this field is required';
                  }
                  if (passwordOrLoginIsIncorrect) {
                    return 'password or login is incorrect';
                  }
                  return null;
                },
                onSaved: (x) {
                  password = x;
                },
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'enter password',
                    helperStyle: TextStyle(fontSize: 16)),
              ),
            ),
            if (workInProgress)
              CircularProgressIndicator()
            else
              ElevatedButton(onPressed: enterPressed, child: Text('Enter')),
          ],
        ),
      ),
    );
  }

  void enterPressed() async {
    passwordOrLoginIsIncorrect = false;
    final formState = _formKey.currentState!;
    final allValid = formState.validate();
    if (!allValid) {
      print('----not all areas fulled');
      return;
    }
    print('input is valid');
    formState.save();
    FocusScope.of(context).unfocus();
    setState(() {
      workInProgress = true;
    });
    bool success = await makeRequest();
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        workInProgress = false;
      });
    }
  }

  Future<bool> makeRequest() async {
    final url = Uri.parse('https://${host}/rest/auth/by-login?apiVersion=1.4');
    try {
      final response = await http.post(url,
          body: '{"login":"$login","password":"$password"}');
      print(response.statusCode);
      print('body = ${response.body}');
      await Future<void>.delayed(Duration(seconds: 3));
      if (response.statusCode == 200) {
        print('success');
        final j = jsonDecode(response.body) as Map<String, dynamic>;
        final fio = j['fio'] as String;
        final token = j['token'] as String;
        final departmentId = j['department_id'] as int?;
        final roleId = j['role_id'] as int;
        print('hello $fio with token=$token');
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('userName', fio);
        prefs.setString('token', token);
        prefs.setInt('departmentId', departmentId ?? 0);
        prefs.setInt('roleId', roleId);
        return true;
      } else {
        if (response.statusCode == 403) {
          passwordOrLoginIsIncorrect = true;
          _formKey.currentState?.validate();
        } else {
          showErrorDialog('${response.statusCode} ${response.body}');
        }
      }
    } catch (ex) {
      print(ex.toString());
      showErrorDialog('no internet? \n $ex');
    }
    return false;
  }

  void showErrorDialog(String errDescription) {
    print(errDescription);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error has occurred!'),
          content: Text(errDescription),
          actions: [
            TextButton(
              style: ButtonStyle(alignment: Alignment.bottomLeft),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Ok'),
            )
          ],
        );
      },
    );
  }
}
