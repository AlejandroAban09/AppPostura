import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class MyStyleScreen extends StatefulWidget {
  const MyStyleScreen({super.key});

  @override
  State<MyStyleScreen> createState() => _MyStyleScreenState();
}

class _MyStyleScreenState extends State<MyStyleScreen> {
  String? selectedPet;
  String? selectedSound;

  final mascotas = ['ZenCat', 'FocusBear', 'Owlight'];
  final sonidos = ['Rain', 'Waves', 'lofi'];

  @override
  void initState() {
    super.initState();
    final box = Hive.box('focusme_users');
    selectedPet = box.get('active_pet');
    selectedSound = box.get('active_sound');
  }

  void _selectPet(String pet) {
    final box = Hive.box('focusme_users');
    box.put('active_pet', pet);
    setState(() => selectedPet = pet);
  }

  void _selectSound(String sound) {
    final box = Hive.box('focusme_users');
    box.put('active_sound', sound);
    setState(() => selectedSound = sound);
  }

  bool _isUnlocked(String key) {
    return Hive.box('focusme_users').get('reward_$key', defaultValue: false);
  }

  Widget _buildPetItem(String pet) {
    final unlocked = _isUnlocked(pet);
    final isSelected = selectedPet == pet;
    final imagePath = 'assets/imagenes/$pet.jpg';

    return GestureDetector(
      onTap: unlocked ? () => _selectPet(pet) : null,
      child: Column(
        children: [
          Image.asset(
            imagePath,
            height: 80,
            color: unlocked ? null : Colors.grey,
            colorBlendMode: BlendMode.saturation,
          ),
          Text(pet,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.blue : Colors.black)),
          if (!unlocked) const Text('Bloqueado', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSoundItem(String sound) {
    final unlocked = _isUnlocked(sound);
    final isSelected = selectedSound == sound;

    return ListTile(
      title: Text(sound),
      trailing: unlocked
          ? (isSelected ? const Icon(Icons.check, color: Colors.green) : null)
          : const Text('Bloqueado', style: TextStyle(color: Colors.grey)),
      onTap: unlocked ? () => _selectSound(sound) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi estilo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Mascotas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: mascotas.map((m) => _buildPetItem(m)).toList(),
            ),
            const SizedBox(height: 30),
            const Text('Sonidos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ...sonidos.map((s) => _buildSoundItem(s)).toList(),
          ],
        ),
      ),
    );
  }
}
