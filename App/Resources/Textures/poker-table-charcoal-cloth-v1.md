# Поверхность учебного покерного стола

Файл: `poker-table-charcoal-cloth-v1.png`. Формат: RGB PNG, 1254 × 1254 px, непрозрачный. Создан один вариант встроенным image_gen; исходное изображение скопировано в проект без изменения пикселей. Существующие ресурсы сохранены.

Назначение: повторяемая тканевая подложка области стола. В SwiftUI использовать повторение тайла с постоянным масштабом и обрезку по форме поля. Для повышения читаемости допустима сплошная тёмная подложка под подписи. Сам PNG содержит только ткань. Подключение к app bundle выполняется при создании Xcode-проекта.

Итоговый запрос генерации:

```text
Use case: stylized-concept. Asset type: original seamless tileable raster texture, square 1024 by 1024, production background for the table region of a native iPhone poker training app. Primary request: a perfectly uniform, extremely subtle fine woven matte cloth / premium dense microfelt texture. Palette: very dark charcoal graphite with a barely perceptible cool slate undertone, centered approximately on sRGB #15191E; fine fibers only slightly lighter/darker. Composition: orthographic flat top-down material swatch filling every pixel edge to edge, no object, no table outline. Truly seamless periodic tile in BOTH X and Y: opposing edges match in color, brightness and weave phase for an invisible repeating texture. Even diffuse lighting and constant average brightness across the whole tile, no focal point, no gradients, no vignette, no directional lighting, no hotspots, no shadows, no seams, no borders. Very low amplitude contrast, quiet and restrained at phone size, legible white playing cards and white UI text will later be placed on top. Original generic fabric, not derived from any particular app or brand. Opaque image. No text, letters, numbers, logos, playing cards, chips, UI elements, watermark, symbols, patterns with recognizable motifs, creases, stains, scratches or decorative elements. Generate ONE final texture only.
```

Генератор вернул 1254 × 1254 px. Визуально проверены равномерность фактуры и отсутствие предметов, текста и элементов интерфейса. Масштаб повторения и читаемость реальных подписей требуют проверки в собранном интерфейсе iPhone.
