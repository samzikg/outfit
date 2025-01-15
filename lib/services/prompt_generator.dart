

class PromptGenerator {
  static Map<String, String> generatePrompt({
    required Map<String, dynamic> preferences,
    required Map<String, dynamic> selectedOutfits,
  }) {
    final List<String> promptParts = [];
    final List<String> negativePromptParts = [];

    // Add base prompt
    promptParts.addAll([
      '(RAW photo, 8k uhd:1.4)',
      '(masterpiece, best quality, ultra detailed:1.2)',
      '(photorealistic, professional photograph:1.3)',
    ]);

    // Add identity-based modifiers
    if (preferences['gender'] != null) {
      promptParts.add('${preferences['gender']} person');
    }

    if (preferences['race'] != null) {
      switch (preferences['race'].toString().toLowerCase()) {
        case 'asian':
          promptParts.addAll(['asian', 'asian ethnicity', 'asian features']);
          negativePromptParts.addAll(['western features', 'european features']);
          break;
        case 'black':
          promptParts.addAll(['dark skin', 'african features']);
          negativePromptParts.addAll(['pale skin', 'asian features']);
          break;
        case 'white':
          promptParts.addAll(['caucasian', 'european features']);
          negativePromptParts.addAll(['asian features', 'african features']);
          break;
      }
    }

    // Add clothing descriptions
    selectedOutfits.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        promptParts.add('wearing $value');
      }
    });

    // Add photography and quality modifiers
    promptParts.addAll([
      'professional studio lighting',
      'high-end fashion photography',
      'clean studio background',
      'professional color grading',
      'detailed skin texture',
      'detailed fabric texture',
      'fashion magazine style'
    ]);

    // Add universal negative prompts
    negativePromptParts.addAll([
      'deformed', 'distorted', 'disfigured',
      'bad anatomy', 'bad proportions', 'mutation',
      'extra limbs', 'cloned face', 'weird colors',
      'blurry', 'duplicate', 'watermark', 'signature',
      'text', 'oversaturated', 'low quality'
    ]);

    return {
      'prompt': promptParts.join(', '),
      'negative_prompt': negativePromptParts.join(', '),
    };
  }
}