import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_config.dart';
import '../services/listing_repository.dart';
import '../shared_widgets.dart';

class SellItemPage extends StatefulWidget {
  const SellItemPage({super.key});

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  String cond = 'Good';
  String cat = 'Furniture';
  bool free = false;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pickupController = TextEditingController(
    text: 'Taman Sri Kajang, Selangor',
  );
  final _listingRepository = ListingRepository();
  final _imagePicker = ImagePicker();
  final _photos = <XFile>[];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _pickupController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final selected = await _imagePicker.pickMultiImage(imageQuality: 80);
    if (!mounted || selected.isEmpty) return;
    setState(() {
      _photos
        ..clear()
        ..addAll(selected.take(3));
    });
  }

  Future<void> _postListing() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      await _listingRepository.createListing(
        title: _titleController.text.trim(),
        category: cat,
        condition: cond,
        price: free ? 0 : double.parse(_priceController.text.trim()),
        description: _descriptionController.text.trim(),
        pickupAddress: _pickupController.text.trim(),
        photos: _photos,
      );
      if (!mounted) return;
      Navigator.pop(context);
      snack(
        context,
        _photos.isEmpty
            ? 'Listing posted!'
            : 'Listing posted with photos!',
      );
    } catch (error) {
      if (mounted) snack(context, 'Could not post listing: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sell an item')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 96,
            child: Row(
              children: [
                InkWell(
                  onTap: _pickPhotos,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 90,
                    width: 90,
                    decoration: BoxDecoration(
                      border: Border.all(color: kGreen),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: kGreen),
                        SizedBox(height: 4),
                        Text('Add photos', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _photos.isEmpty
                      ? const Text(
                          'Add up to 3 photos. They will be synced with the listing.',
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, index) => Image.file(
                            File(_photos[index].path),
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (value) => value?.trim().isEmpty == true
                ? 'Add a title.'
                : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: cat,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              'Furniture',
              'Electronics',
              'Fashion',
              'Books',
              'Home',
              'Sports',
              'Kids',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (value) => setState(() => cat = value!),
          ),
          const SizedBox(height: 14),
          const Text('Condition', style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 8,
            children: ['New', 'Like new', 'Good', 'Fair']
                .map(
                  (value) => ChoiceChip(
                    label: Text(value),
                    selected: cond == value,
                    onSelected: (_) => setState(() => cond = value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Give away for free'),
            subtitle: const Text('Earn double eco points'),
            value: free,
            onChanged: (value) => setState(() => free = value),
          ),
          if (!free)
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: 'RM ',
              ),
              validator: (value) {
                final price = double.tryParse(value?.trim() ?? '');
                return price == null || price < 0
                    ? 'Enter a valid price.'
                    : null;
              },
            ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
            validator: (value) => value?.trim().isEmpty == true
                ? 'Add a short description.'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pickupController,
            decoration: const InputDecoration(
              labelText: 'Pickup location',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator: (value) => value?.trim().isEmpty == true
                ? 'Add a pickup location.'
                : null,
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: _isSubmitting ? null : _postListing,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post listing'),
          ),
        ],
      ),
    ),
  );
}
