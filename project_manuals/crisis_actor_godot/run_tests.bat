@echo off
echo Running viewer_smoke_test.gd...
"D:\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" --path C:/Users/zeros/.gemini/antigravity/scratch/project_manuals/crisis_actor_godot --headless -s tests/viewer_smoke_test.gd > smoke_output.txt 2>&1
echo Done.
