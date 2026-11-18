#!/usr/bin/env bash
# Gera assets/esqueletos/<Modelo>_Anim.glb juntando as animações dos rigs KayKit.
# Precisa que o editor Doriax já tenha convertido os .fbx (pasta .doriax/imported/):
# basta abrir o projeto ou dar Play uma vez depois de adicionar os arquivos.
set -e
cd "$(dirname "$0")/.."
RIG=.doriax/imported/animacoes/Rig_Medium
RIGS=$RIG/Rig_Medium_Special.fbx.glb,$RIG/Rig_Medium_General.fbx.glb,$RIG/Rig_Medium_Simulation.fbx.glb
ANIMS=Skeletons_Inactive_Floor_Pose,Skeletons_Awaken_Floor,Skeletons_Idle,Skeletons_Taunt,Skeletons_Death,Skeletons_Death_Pose,Skeletons_Walking,Hit_A,Interact,Lie_Down,Lie_Idle,Waving,Use_Item
for MODEL in Skeleton_Minion Skeleton_Warrior Skeleton_Mage Skeleton_Rogue Necromancer; do
    node tools/merge_anims.js ".doriax/imported/esqueletos/$MODEL.fbx.glb" "assets/esqueletos/${MODEL}_Anim.glb" "$RIGS" "$ANIMS" | tail -1
done
