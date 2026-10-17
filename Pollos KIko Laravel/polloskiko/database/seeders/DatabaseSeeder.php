<?php

namespace Database\Seeders;

use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        Role::create(['id' => 1, 'nombre' => 'Administrador']);
        Role::create(['id' => 2, 'nombre' => 'Cajero']);

        User::create([
            'name'      => 'Admin',
            'apellidos' => 'Kiko',
            'domicilio' => 'Teapa, Tabasco',
            'telefono'  => '0000000000',
            'email'     => 'admin@polloskiko.com',
            'password'  => 'cambiame123',
            'role_id'   => 1,
        ]);
    }
}