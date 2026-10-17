<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        
        Schema::create('roles', function (Blueprint $table) {
            $table->id();
            $table->string('nombre', 30)->unique();
            $table->timestamps();
        });

        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('apellidos')->nullable();
            $table->string('domicilio')->nullable();
            $table->string('telefono', 20)->nullable();
            $table->string('email')->unique();
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');
            $table->boolean('activo')->default(true);
            $table->foreignId('role_id')->default(2)->constrained('roles');
            $table->rememberToken();
            $table->timestamps();
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
        Schema::create('clientes', function (Blueprint $table) {
         $table->id();
         $table->string('nombre', 80);
         $table->string('telefono', 20);
         $table->string('direccion', 150)->nullable();
         $table->timestamps();
        });
        Schema::create('productos', function (Blueprint $table) {
          $table->id();
          $table->string('nombre', 80);
          $table->unsignedInteger('stock')->default(0);
         $table->decimal('precio_venta', 10, 2);
         $table->timestamps();
        });
        Schema::create('proveedores', function (Blueprint $table) {
          $table->id();
          $table->string('nombre', 80);
          $table->string('direccion', 150);
          $table->string('telefono', 20);
         $table->string('materias_surtidas', 200)->nullable();
         $table->decimal('adeudo', 10, 2)->default(0);
         $table->timestamps();
        }); 

        Schema::create('ventas', function (Blueprint $table) {
         $table->id();
         $table->foreignId('user_id')->constrained('users');
         $table->foreignId('cliente_id')->nullable()->constrained('clientes')->nullOnDelete();
         $table->decimal('total', 10, 2);
         $table->timestamps();
        });

        Schema::create('detalle_ventas', function (Blueprint $table) {
          $table->id();
          $table->foreignId('venta_id')->constrained('ventas')->cascadeOnDelete();
          $table->foreignId('producto_id')->constrained('productos');
          $table->unsignedInteger('cantidad');
          $table->decimal('precio_unitario', 10, 2);
          $table->timestamps();
});
    }

    public function down(): void
    {
     Schema::dropIfExists('detalle_ventas');
     Schema::dropIfExists('ventas');
     Schema::dropIfExists('proveedores');
     Schema::dropIfExists('productos');
     Schema::dropIfExists('clientes');
     Schema::dropIfExists('sessions');
     Schema::dropIfExists('password_reset_tokens');
     Schema::dropIfExists('users');
     Schema::dropIfExists('roles');
    }
};