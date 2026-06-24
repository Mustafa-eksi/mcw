module mcw.apps.test;

import std.conv : to;
import std.math : sin, cos;
import std.range : back;
import std.algorithm : map;

import bindbc.sdl;

import mcw.window;
import mcw.widgets;

class LayoutTestWindow : Window {
    Box main_box;
    Box[] boxes;
    Label[] labels;
    uint frame;
    float period, speed;

    this (SDL_FRect rect, string title, TTF_Font *font) {
        super(rect, title);
        main_box = new Box(rect, renderer, 5, Box.Orientation.Vertical);
        main_box.style.background_color = SDL_Color(100, 0, 0, 255);
        main_box.style.border_color = SDL_Color(0, 100, 0, 255);

        for (int i = 0; i < 5; i++) {
            boxes ~= new Box(rect, renderer, 5, Box.Orientation.Horizontal);
            main_box.addChild(boxes[i]);

            for (int j = 0; j < 5; j++) {
                labels ~= new Label(rect, renderer, font, (i*5+j).to!string);
                boxes.back.addChild(labels.back);
            }

        }
        main_box.applyStyleToChildren();

        widget = main_box;
        period = 0.0002;
        speed = 0.02;
    }

    override void draw() {
        // box.style.background_color =
        //     SDL_Color(
        //         cast(ubyte)(((sin(frame.to!float * period) + 1) / 2) * 255),
        //         cast(ubyte)(((cos(frame.to!float * period) + 1) / 2) * 255),
        //         cast(ubyte)(((sin(frame.to!float * period * 1.1) + 1) / 2) * 255), 255);
        this.Window.draw();
        frame++;
    }
}
