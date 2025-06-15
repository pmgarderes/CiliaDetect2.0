# CiliaDetect 🧬

Semi-automated MATLAB tool for detecting and quantifying cilia from ND2 image stacks.

---

## 🔧 Features

- **Downsample ND2 stacks** with customizable averaging factor  
- **Interactive GUI** for detection:  
  - Switch channels and Z-planes with ← → and ↑ ↓  
  - Click (`Spacebar`) to detect individual cilia  
  - Undo (`u`), refresh (`r`), suppress (`s`), merge (`m`) detected ROIs  
  - Display cilia count  
  - Auto-detection seed support (via button)  
- **Fluorescence quantification** across all four channels (mean or sum), with background correction  
- **Export capabilities**:  
  - Save all detections (`.mat`)  
  - Quantification results exported to `.xlsx` table

---

## 🧭 Main Workflow (`Wrapper_Cilia_Process.m`)

```matlab
% 1. Paths and batch downsampling of ND2 files:
batch_downsample_nd2_folder(foldername, DSfactor, true);

% 2. Load image stack (downsampled .mat or ND2)
[imgStack, metadata] = load_nd2_image_downsampled(filename, params);

% 3. Open GUI to detect cilia
view_nd2_with_cilia_gui(imgStack, params, uniqueDetections);

% 4. Clean overlapping ROIs
uniqueDetections = deduplicate_cilia_detections(ciliaDetections, params.maxroiOverlap);

% 5. Save detections (.mat paired with source)
save_cilia_detections(filename, ciliaDetections, uniqueDetections);

% 6. Visualize masks
visualize_cilia_masks(imgStack, uniqueDetections, params);

% 7. Quantify fluorescence & export to Excel
results = quantify_cilia_fluorescence2(imgStack, uniqueDetections, params);
writetable(struct2table(results), fullfile(...));
