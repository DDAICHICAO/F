import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/v2board/api/api_paths.dart';
import 'package:fl_clash/v2board/api/v2board_api.dart';
import 'package:fl_clash/v2board/models/ticket.dart';

class TicketApi {
  Future<List<Ticket>> fetchList() async {
    final data = await v2boardApi.get(ApiPaths.ticketFetch);
    final list = data['data'] as List? ?? [];
    return list.map((e) => Ticket.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Ticket> fetchDetail(int id) async {
    final data = await v2boardApi.get(
      ApiPaths.ticketFetch,
      queryParameters: {'id': id},
    );
    return Ticket.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> create({
    required String subject,
    required int level,
    required String message,
    List<String>? images,
  }) async {
    final body = <String, dynamic>{
      'subject': subject,
      'level': level,
      'message': message,
    };
    if (images != null && images.isNotEmpty) {
      body['images'] = images;
    }
    await v2boardApi.post(ApiPaths.ticketSave, data: body);
  }

  Future<void> reply({
    required int id,
    required String message,
    List<String>? images,
  }) async {
    final body = <String, dynamic>{
      'id': id,
      'message': message,
    };
    if (images != null && images.isNotEmpty) {
      body['images'] = images;
    }
    await v2boardApi.post(ApiPaths.ticketReply, data: body);
  }

  Future<void> close(int id) async {
    await v2boardApi.post(ApiPaths.ticketClose, data: {'id': id});
  }

  Future<List<String>> upload(List<File> files) async {
    final formData = FormData();
    for (int i = 0; i < files.length && i < 5; i++) {
      formData.files.add(MapEntry(
        'images[$i]',
        await MultipartFile.fromFile(files[i].path),
      ));
    }
    final response = await v2boardApi.post(
      ApiPaths.ticketUpload,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final urls = response['data'] as List? ?? [];
    return urls.map((e) => e.toString()).toList();
  }
}

final ticketApi = TicketApi();
