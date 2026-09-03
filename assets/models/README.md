# On-device art era model

A tiny MLP (`era_mlp.json`) runs entirely on the phone. It maps a photo to:

Renaissance, Baroque, Romanticism, Realism, Impressionism, Post-Impressionism, Modern, Contemporary.

Rebuild weights:

```
.venv/bin/python tools/train_era_model.py
```
